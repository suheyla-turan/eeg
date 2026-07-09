import json
import ssl
import websocket

from config import *


class CortexClient:

    def __init__(self):

        self.ws = None
        self.token = None
        self.session_id = None
        self.headset_id = None

    # -------------------------
    # Connect
    # -------------------------
    def connect(self):

        print("Cortex API'ye bağlanılıyor...")

        self.ws = websocket.create_connection(
            URL,
            sslopt={"cert_reqs": ssl.CERT_NONE}
        )

        print("Bağlantı başarılı.")

    # -------------------------
    # Send
    # -------------------------
    def send(self, data):

        self.ws.send(json.dumps(data))

    # -------------------------
    # Receive
    # -------------------------
    def receive(self):

        return json.loads(self.ws.recv())

    # -------------------------
    # Request Access
    # -------------------------
    def request_access(self):

        request = {
            "id": 1,
            "jsonrpc": "2.0",
            "method": "requestAccess",
            "params": {
                "clientId": CLIENT_ID,
                "clientSecret": CLIENT_SECRET
            }
        }

        self.send(request)

        response = self.receive()

        print(response)

        if response["result"]["accessGranted"]:
            print("Uygulama erişim izni alındı.")
        else:
            raise Exception("Access reddedildi.")

    # -------------------------
    # Authorize
    # -------------------------
    def authorize(self):

        request = {
            "id": 2,
            "jsonrpc": "2.0",
            "method": "authorize",
            "params": {
                "clientId": CLIENT_ID,
                "clientSecret": CLIENT_SECRET,
                "license": LICENSE,
                "debit": DEBIT
            }
        }

        self.send(request)

        response = self.receive()

        print(response)

        self.token = response["result"]["cortexToken"]

        print("Authorize başarılı.")

    # -------------------------
    # Query Headsets
    # -------------------------
    def query_headsets(self):

        request = {
            "id": 3,
            "jsonrpc": "2.0",
            "method": "queryHeadsets",
            "params": {}
        }

        self.send(request)

        response = self.receive()

        print(response)

        headset = response["result"][0]

        self.headset_id = headset["id"]

        print("Headset :", self.headset_id)

    # -------------------------
    # Create Session
    # -------------------------
    def create_session(self):

        request = {
            "id": 4,
            "jsonrpc": "2.0",
            "method": "createSession",
            "params": {
                "cortexToken": self.token,
                "headset": self.headset_id,
                "status": "active"
            }
        }

        self.send(request)

        response = self.receive()

        print(response)

        self.session_id = response["result"]["id"]

        print("Session oluşturuldu.")

    # -------------------------
    # Subscribe DEV
    # -------------------------
    def subscribe_dev(self):

        request = {
            "id": 5,
            "jsonrpc": "2.0",
            "method": "subscribe",
            "params": {
                "cortexToken": self.token,
                "session": self.session_id,
                "streams": ["dev"]
            }
        }

        self.send(request)

        response = self.receive()

        print(response)

        result = response["result"]

        if len(result["success"]) > 0:

            print("\nDEV stream bağlandı.\n")

        else:

            print(result["failure"])

    # -------------------------
    # Listen
    # -------------------------
    def listen(self):

        channels = [
            "AF3", "F7", "F3", "FC5",
            "T7", "P7", "O1", "O2",
            "P8", "T8", "FC6", "F4",
            "F8", "AF4", "OVERALL"
        ]

        print("\nVeriler dinleniyor...\n")

        while True:

            try:

                message = self.receive()

                if "dev" not in message:
                    continue

                battery = message["dev"][0]
                signal = message["dev"][1]
                sensors = message["dev"][2]
                battery_percent = message["dev"][3]

                print("=" * 60)

                print(f"Batarya      : %{battery_percent}")
                print(f"Sinyal       : {signal}")

                print()

                for name, value in zip(channels, sensors):

                    print(f"{name:<10}: {value}")

            except KeyboardInterrupt:

                print("\nProgram sonlandırıldı.")

                break

    # -------------------------
    # Disconnect
    # -------------------------
    def disconnect(self):

        if self.ws:
            self.ws.close()

            print("Bağlantı kapatıldı.")