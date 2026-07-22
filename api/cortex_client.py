import json
import ssl
import threading
import time

import websocket

from config import *
import live_state


class CortexClient:
    def __init__(self):
        self.ws = None
        self.token = None
        self.session_id = None
        self.headset_id = None
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    # Cortex sessiz kalırsa (cihaz kapandı / stream koptu) yeniden bağlan
    RECV_TIMEOUT_SEC = 5
    SILENCE_RECONNECT_SEC = 8

    def connect(self):
        print("Cortex API'ye bağlanılıyor...")
        live_state.set_connecting()
        self.ws = websocket.create_connection(
            URL,
            sslopt={"cert_reqs": ssl.CERT_NONE},
            timeout=self.RECV_TIMEOUT_SEC,
        )
        print("Bağlantı başarılı.")

    def send(self, data):
        self.ws.send(json.dumps(data))

    def receive(self):
        return json.loads(self.ws.recv())

    def receive_rpc(self, expected_id: int, timeout_sec: float = 15.0):
        """JSON-RPC yanıtını bekle; arada gelen DEV/EEG stream paketlerini işle.

        DEV aboneliğinden sonra stream paketleri RPC yanıtıyla karışır;
        düz receive() EEG aboneliğini yanlışlıkla başarısız sayıyordu.
        """
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            remaining = max(0.5, deadline - time.time())
            self.ws.settimeout(remaining)
            try:
                message = self.receive()
            except Exception as exc:
                raise TimeoutError(
                    f"Cortex RPC id={expected_id} zaman aşımı: {exc}"
                ) from exc

            # Stream veri paketi (dev/eeg/pow) — RPC değil
            if "dev" in message or "eeg" in message or "pow" in message:
                if "dev" in message:
                    live_state.update_from_dev(message["dev"])
                if "eeg" in message:
                    live_state.update_from_eeg(
                        message["eeg"], timestamp=message.get("time")
                    )
                if "pow" in message:
                    live_state.update_from_pow(
                        message["pow"], timestamp=message.get("time")
                    )
                continue

            if message.get("id") == expected_id:
                return message

            # Başka RPC / warning — yok say
            continue

        raise TimeoutError(f"Cortex RPC id={expected_id} yanıt vermedi")

    def request_access(self):
        request = {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "requestAccess",
            "params": {
                "clientId": CLIENT_ID,
                "clientSecret": CLIENT_SECRET,
            },
        }
        self.send(request)
        response = self.receive_rpc(1)
        print(response)
        if response["result"]["accessGranted"]:
            print("Uygulama erişim izni alındı.")
        else:
            raise Exception("Access reddedildi.")

    def authorize(self):
        request = {
            "id": 2,
            "jsonrpc": "2.0",
            "method": "authorize",
            "params": {
                "clientId": CLIENT_ID,
                "clientSecret": CLIENT_SECRET,
                "license": LICENSE,
                "debit": DEBIT,
            },
        }
        self.send(request)
        response = self.receive_rpc(2)
        print(response)
        self.token = response["result"]["cortexToken"]
        print("Authorize başarılı.")

    def query_headsets(self):
        request = {
            "id": 3,
            "jsonrpc": "2.0",
            "method": "queryHeadsets",
            "params": {},
        }
        self.send(request)
        response = self.receive_rpc(3)
        print(response)

        result = response.get("result") or []
        if not result:
            raise Exception(
                "Headset bulunamadı. Emotiv cihazını açıp Bluetooth ile bağla, "
                "Emotiv Launcher'da görünür olduğundan emin ol."
            )

        headset = result[0]
        self.headset_id = headset["id"]
        print("Headset :", self.headset_id)
        live_state.set_device_found(self.headset_id)

    def create_session(self):
        request = {
            "id": 4,
            "jsonrpc": "2.0",
            "method": "createSession",
            "params": {
                "cortexToken": self.token,
                "headset": self.headset_id,
                "status": "active",
            },
        }
        self.send(request)
        response = self.receive_rpc(4)
        print(response)
        self.session_id = response["result"]["id"]
        print("Session oluşturuldu.")

    def subscribe_streams(self):
        """DEV zorunlu; EEG tercih; EEG yoksa POW (bant gücü) yedek."""
        request = {
            "id": 5,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": ["dev", "eeg", "pow"],
            },
        }
        self.send(request)
        response = self.receive_rpc(5)
        print(response)

        ok_streams, failure, cols_by_stream = self._parse_subscribe_result(response)
        eeg_ok = "eeg" in ok_streams
        pow_ok = "pow" in ok_streams
        dev_ok = "dev" in ok_streams

        if not dev_ok:
            print("DEV eksik, ayrı deneniyor:", failure)
            self._subscribe_named(["dev"], req_id=7, required=True)

        if not eeg_ok:
            print("EEG yok (lisans -32016 olabilir):", failure)
            eeg_ok = self._subscribe_named(["eeg"], req_id=8, required=False)

        if not pow_ok:
            pow_ok, pow_cols = self._subscribe_named_with_cols(
                ["pow"], req_id=9, required=False
            )
            if pow_ok and pow_cols:
                live_state.set_pow_subscribed(True, pow_cols)
        else:
            live_state.set_pow_subscribed(True, cols_by_stream.get("pow"))

        live_state.set_eeg_subscribed(eeg_ok)

        if eeg_ok:
            print("\nDEV + EEG stream bağlandı.\n")
        elif pow_ok:
            print(
                "\nDEV + POW stream bağlandı "
                "(ham EEG lisansı yok — bant güçleri POW'dan).\n"
            )
        else:
            print(
                "\nUYARI: EEG ve POW yok — yalnızca DEV. "
                "Bilişsel skor üretilemez.\n"
            )
        live_state.set_connected()

    def _parse_subscribe_result(
        self, response: dict
    ) -> tuple[set[str], list, dict[str, list]]:
        if "error" in response:
            return set(), [response["error"]], {}
        result = response.get("result") or {}
        success = result.get("success") or []
        failure = result.get("failure") or []
        ok_streams: set[str] = set()
        cols_by_stream: dict[str, list] = {}
        for item in success:
            if isinstance(item, dict):
                name = item.get("streamName") or item.get("stream")
                if name:
                    name = str(name)
                    ok_streams.add(name)
                    cols = item.get("cols")
                    if isinstance(cols, list):
                        cols_by_stream[name] = list(cols)
            elif isinstance(item, str):
                ok_streams.add(item)
        return ok_streams, list(failure), cols_by_stream

    def _subscribe_named(
        self, streams: list[str], req_id: int, required: bool = True
    ) -> bool:
        ok, _ = self._subscribe_named_with_cols(streams, req_id, required)
        return ok

    def _subscribe_named_with_cols(
        self, streams: list[str], req_id: int, required: bool = True
    ) -> tuple[bool, list | None]:
        request = {
            "id": req_id,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": streams,
            },
        }
        self.send(request)
        response = self.receive_rpc(req_id)
        print(response)
        ok_streams, failure, cols_by_stream = self._parse_subscribe_result(response)
        wanted = set(streams)
        ok = bool(wanted & ok_streams)
        cols = None
        for s in streams:
            if s in cols_by_stream:
                cols = cols_by_stream[s]
                break
        if ok:
            return True, cols
        print(f"Abonelik başarısız {streams}:", failure or response)
        if required:
            raise Exception(f"Stream aboneliği başarısız: {streams}")
        return False, None

    def listen(self):
        channels = live_state.CHANNELS + ["OVERALL"]
        print("\nCihaz durumu ve spektral veri dinleniyor...\n")
        last_packet_at = time.time()

        while not self._stop.is_set():
            try:
                message = self.receive()
                has_dev = "dev" in message
                has_eeg = "eeg" in message
                has_pow = "pow" in message

                if not has_dev and not has_eeg and not has_pow:
                    if time.time() - last_packet_at > self.SILENCE_RECONNECT_SEC:
                        raise TimeoutError(
                            f"Stream {self.SILENCE_RECONNECT_SEC}s sessiz — yeniden bağlanılıyor"
                        )
                    continue

                last_packet_at = time.time()

                if has_dev:
                    live_state.update_from_dev(message["dev"])
                    battery = message["dev"][0]
                    signal = message["dev"][1]
                    sensors = message["dev"][2]
                    battery_percent = message["dev"][3]

                    print("=" * 60)
                    print(f"Batarya      : %{battery_percent}")
                    print(f"Sinyal       : {signal}")
                    print(
                        f"Toplama      : "
                        f"{'AÇIK' if live_state.is_collecting() else 'kapalı'}"
                    )
                    print()
                    for name, value in zip(channels, sensors):
                        print(f"{name:<10}: {value}")

                if has_eeg:
                    ts = message.get("time")
                    live_state.update_from_eeg(message["eeg"], timestamp=ts)

                if has_pow:
                    live_state.update_from_pow(
                        message["pow"], timestamp=message.get("time")
                    )
                    bp = live_state.snapshot().get("band_power") or {}
                    print(
                        f"POW α={bp.get('alpha', 0):.3f} "
                        f"β={bp.get('beta', 0):.3f} "
                        f"θ={bp.get('theta', 0):.3f}"
                    )

            except KeyboardInterrupt:
                print("\nProgram sonlandırıldı.")
                break
            except Exception as exc:
                if self._stop.is_set():
                    break
                print(f"Dinleme hatası: {exc}")
                live_state.set_disconnected(str(exc))
                break

    @property
    def is_running(self) -> bool:
        return (
            self._thread is not None
            and self._thread.is_alive()
            and not self._stop.is_set()
        )

    def start_background(self):
        """Cortex bağlantısını arka planda başlatır (cihaz durumu / EEG).

        Veri toplama (collecting) bundan bağımsızdır — API startup'ta çağrılır.
        """
        if self.is_running:
            return

        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)

        self._stop.clear()

        def runner():
            while not self._stop.is_set():
                try:
                    self.connect()
                    self.request_access()
                    self.authorize()
                    self.query_headsets()
                    self.create_session()
                    self.subscribe_streams()
                    self.listen()
                except Exception as exc:
                    print(f"Cortex hatası: {exc}")
                    live_state.set_disconnected(str(exc))
                finally:
                    try:
                        self.disconnect()
                    except Exception:
                        pass
                if self._stop.wait(3):
                    break

        self._thread = threading.Thread(target=runner, daemon=True)
        self._thread.start()
        print("Cortex arka plan bağlantısı başlatıldı (otomatik yeniden bağlanma aktif).")

    def stop(self):
        """API kapanırken Cortex thread'ini ve WebSocket'i tamamen durdurur."""
        self._stop.set()
        self.disconnect()

    def disconnect(self):
        if self.ws:
            try:
                self.ws.close()
            except Exception:
                pass
            self.ws = None
            print("Bağlantı kapatıldı.")
        live_state.set_disconnected()
