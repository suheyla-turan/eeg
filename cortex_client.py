import json
import ssl
from datetime import datetime, timezone

import requests
import websocket

from config import *


class CortexClient:

    def __init__(self):
        self.ws = None
        self.token = None
        self.session_id = None
        self.headset_id = None

    def connect(self):
        print("Cortex API'ye bağlanılıyor...")
        self.ws = websocket.create_connection(
            URL,
            sslopt={"cert_reqs": ssl.CERT_NONE},
        )
        print("Bağlantı başarılı.")

    def send(self, data):
        self.ws.send(json.dumps(data))

    def receive(self):
        return json.loads(self.ws.recv())

    def _post_backend(self, path: str, payload: dict) -> None:
        try:
            requests.post(f"{BACKEND_URL}{path}", json=payload, timeout=2)
        except requests.RequestException as error:
            print(f"Backend gönderim hatası ({path}): {error}")

    def _notify_device_status(
        self,
        connected: bool,
        message: str,
    ) -> None:
        self._post_backend(
            "/api/device/status",
            {
                "connected": connected,
                "headset_id": self.headset_id,
                "session_id": self.session_id,
                "message": message,
            },
        )

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

        if "result" in response and response["result"]["accessGranted"]:
            print("Uygulama erişim izni alındı.")
        else:
            raise Exception("requestAccess başarısız.")

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

        if "result" in response:
            self.token = response["result"]["cortexToken"]
            print("Authorize başarılı.")
        else:
            raise Exception("Authorize başarısız.")

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

        if "result" not in response or len(response["result"]) == 0:
            raise Exception("Headset bulunamadı.")

        headset = response["result"][0]
        self.headset_id = headset["id"]
        print(f"Headset bulundu : {self.headset_id}")

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

        if "result" in response:
            self.session_id = response["result"]["id"]
            print(f"Session oluşturuldu : {self.session_id}")
        else:
            raise Exception("Session oluşturulamadı.")

    def subscribe_eeg(self):
        request = {
            "id": 5,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": ["eeg"],
            },
        }

        self.send(request)
        response = self.receive()
        print(response)

        if "result" in response:
            print("EEG stream aboneliği başarılı.")
            self._notify_device_status(True, "EEG verisi alınıyor")
        else:
            raise Exception("EEG stream aboneliği başarısız.")

    def _send_eeg_to_backend(self, eeg_values: list) -> None:
        numeric_channels = []

        for value in eeg_values:
            try:
                numeric_channels.append(float(value))
            except (TypeError, ValueError):
                continue

        self._post_backend(
            "/api/eeg",
            {
                "channels": numeric_channels,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "raw": {"eeg": eeg_values},
            },
        )

    def listen(self):
        print("\nEEG verileri dinleniyor...\n")

        while True:
            try:
                message = self.receive()

                if "eeg" in message:
                    eeg_values = message["eeg"]
                    print("EEG :", eeg_values)
                    self._send_eeg_to_backend(eeg_values)

            except KeyboardInterrupt:
                print("\nDinleme durduruldu.")
                break

    def disconnect(self):
        if self.ws:
            self._notify_device_status(False, "Bağlantı kapatıldı")
            self.ws.close()
            print("Bağlantı kapatıldı.")
