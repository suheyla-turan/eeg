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
        response = self.receive()
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
        response = self.receive()
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
        response = self.receive()
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
        response = self.receive()
        print(response)
        self.session_id = response["result"]["id"]
        print("Session oluşturuldu.")

    def subscribe_streams(self):
        """DEV (cihaz durumu) + EEG (14 kanal ham sinyal) aboneliği."""
        request = {
            "id": 5,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": ["dev", "eeg"],
            },
        }
        self.send(request)
        response = self.receive()
        print(response)
        result = response.get("result") or {}
        success = result.get("success") or []
        failure = result.get("failure") or []

        ok_streams: set[str] = set()
        for item in success:
            if isinstance(item, dict):
                name = item.get("streamName") or item.get("stream")
                if name:
                    ok_streams.add(str(name))
            elif isinstance(item, str):
                ok_streams.add(item)

        if not success and not ok_streams:
            # Kısmi başarı yok — yalnızca DEV dene
            print("DEV+EEG aboneliği başarısız, yalnızca DEV deneniyor:", failure)
            self._subscribe_dev_only()
            return

        if "eeg" in ok_streams:
            print("\nDEV + EEG stream bağlandı.\n")
        else:
            print("\nDEV stream bağlandı (EEG yok / lisans gerekebilir).\n")
            if failure:
                print("EEG failure:", failure)

        live_state.set_connected()

    def _subscribe_dev_only(self):
        request = {
            "id": 6,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": ["dev"],
            },
        }
        self.send(request)
        response = self.receive()
        print(response)
        result = response.get("result") or {}
        if result.get("success"):
            print("\nDEV stream bağlandı (EEG yok).\n")
            live_state.set_connected()
        else:
            print(result.get("failure"))
            raise Exception("DEV stream aboneliği başarısız.")

    def listen(self):
        channels = live_state.CHANNELS + ["OVERALL"]
        print("\nCihaz durumu ve EEG dinleniyor...\n")
        last_packet_at = time.time()

        while not self._stop.is_set():
            try:
                message = self.receive()
                has_dev = "dev" in message
                has_eeg = "eeg" in message

                if not has_dev and not has_eeg:
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
