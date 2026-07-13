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

    def subscribe_dev(self):
        request = {
            "id": 5,
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
        result = response["result"]
        if len(result["success"]) > 0:
            print("\nDEV stream bağlandı.\n")
            live_state.set_connected()
        else:
            print(result["failure"])
            raise Exception("DEV stream aboneliği başarısız.")

    def listen(self):
        channels = live_state.CHANNELS + ["OVERALL"]
        print("\nVeriler dinleniyor...\n")
        last_dev_at = time.time()

        while not self._stop.is_set():
            try:
                message = self.receive()
                if "dev" not in message:
                    # Keepalive / diğer mesajlar — sessizlik sayacını bozma
                    if time.time() - last_dev_at > self.SILENCE_RECONNECT_SEC:
                        raise TimeoutError(
                            f"DEV stream {self.SILENCE_RECONNECT_SEC}s sessiz — yeniden bağlanılıyor"
                        )
                    continue

                last_dev_at = time.time()
                battery = message["dev"][0]
                signal = message["dev"][1]
                sensors = message["dev"][2]
                battery_percent = message["dev"][3]

                live_state.update_from_dev(message["dev"])

                print("=" * 60)
                print(f"Batarya      : %{battery_percent}")
                print(f"Sinyal       : {signal}")
                print()
                for name, value in zip(channels, sensors):
                    print(f"{name:<10}: {value}")

            except KeyboardInterrupt:
                print("\nProgram sonlandırıldı.")
                break
            except Exception as exc:
                if self._stop.is_set():
                    break
                print(f"Dinleme hatası: {exc}")
                live_state.set_disconnected(str(exc))
                # Timeout / sessizlik → dış runner yeniden bağlansın
                break

    @property
    def is_running(self) -> bool:
        return (
            self._thread is not None
            and self._thread.is_alive()
            and not self._stop.is_set()
        )

    def start_background(self):
        """Cortex bağlantısını arka planda başlatır (API sunucusu için)."""
        if self.is_running:
            return

        # Önceki stop sonrası thread hâlâ kapanıyorsa bekle
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2.0)

        self._stop.clear()
        live_state.set_collecting(True)

        def runner():
            while not self._stop.is_set():
                try:
                    self.connect()
                    self.request_access()
                    self.authorize()
                    self.query_headsets()
                    self.create_session()
                    self.subscribe_dev()
                    self.listen()
                except Exception as exc:
                    print(f"Cortex hatası: {exc}")
                    live_state.set_disconnected(str(exc))
                finally:
                    try:
                        self.disconnect()
                    except Exception:
                        pass
                # Stream koptu / headset yok → 3 sn sonra tekrar dene
                if self._stop.wait(3):
                    break

        self._thread = threading.Thread(target=runner, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        live_state.set_collecting(False)
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
