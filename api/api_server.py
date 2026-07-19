"""
EEG canlı veri API'si.

Emotiv Cortex'ten gelen DEV + EEG stream'lerini Flutter uygulamasına sunar.

Başlangıçta Cortex'e otomatik bağlanır (requestAccess → authorize →
queryHeadsets → createSession → subscribe DEV+EEG). Cihaz durumu (pil, sinyal,
contact quality) ve 14 kanal EEG sürekli güncellenir.

Bağlantı durumları:
  disconnected | connecting | device_found | device_not_worn | connected

Veri toplama (recording/processing) Flutter'dan
POST /collection/start ve /collection/stop ile kontrol edilir.
Durdurma Cortex bağlantısını kesmez.

Çalıştırma:
  pip install -r requirements.txt
  python api_server.py

mDNS: http://eegserver.local:8000  (servis: _eeg-api._tcp)

Endpoint'ler:
  GET  /health
  GET  /live
  GET  /collection/status
  POST /collection/start
  POST /collection/stop
  WS   /ws/live
"""

from __future__ import annotations

import asyncio
import json
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from cortex_client import CortexClient
from mdns_advertise import MdnsAdvertiser
import live_state

mdns = MdnsAdvertiser(port=8000)
cortex = CortexClient()


@asynccontextmanager
async def lifespan(app: FastAPI):
    live_state.set_collecting(False)
    live_state.set_disconnected("Cortex'e bağlanılıyor…")
    print("API hazır. Cortex'e otomatik bağlanılıyor (cihaz durumu / DEV stream).")
    try:
        await mdns.start()
    except Exception as exc:
        print(f"mDNS başlatılamadı (API yine de çalışır): {exc!r}")
    # Cihaz izleme hemen başlar; collecting ayrı (Başlat butonu)
    cortex.start_background()
    yield
    await mdns.stop()
    live_state.set_collecting(False)
    cortex.stop()


app = FastAPI(title="EEG Live API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    state = live_state.snapshot()
    return {
        "ok": True,
        "connection": state["connection"],
        "collecting": state.get("collecting", False),
        "updated_at": state["updated_at"],
    }


@app.get("/live")
def live():
    """Flutter'ın periyodik olarak çektiği anlık durum."""
    return live_state.snapshot()


@app.get("/collection/status")
def collection_status():
    state = live_state.snapshot()
    return {
        "collecting": state.get("collecting", False),
        "running": cortex.is_running,
        "connection": state["connection"],
    }


@app.post("/collection/start")
def collection_start():
    """Flutter Başlat — yalnızca EEG veri işlemeyi / kaydı açar.

    Cortex oturumu ve DEV stream zaten açık kalır.
    """
    if not cortex.is_running:
        print("Cortex henüz çalışmıyor — bağlantı başlatılıyor.")
        cortex.start_background()

    state = live_state.snapshot()
    if state.get("collecting"):
        return {
            "ok": True,
            "collecting": True,
            "message": "Veri toplama zaten açık",
            "connection": state["connection"],
        }

    print("Flutter'dan veri toplama (EEG işleme) başlatıldı.")
    live_state.set_collecting(True)
    return {
        "ok": True,
        "collecting": True,
        "message": "Veri toplama başladı",
        "connection": live_state.snapshot()["connection"],
    }


@app.post("/collection/stop")
def collection_stop():
    """Flutter Durdur — yalnızca veri işlemeyi kapatır.

    Cortex bağlantısı, session ve DEV stream açık kalır.
    """
    print("Flutter'dan veri toplama durduruldu (cihaz bağlantısı korunuyor).")
    live_state.set_collecting(False)
    return {
        "ok": True,
        "collecting": False,
        "message": "Veri toplama durduruldu",
        "connection": live_state.snapshot()["connection"],
    }


@app.websocket("/ws/live")
async def ws_live(websocket: WebSocket):
    """İsteğe bağlı WebSocket akışı (~10 Hz)."""
    await websocket.accept()
    try:
        while True:
            await websocket.send_text(json.dumps(live_state.snapshot()))
            await asyncio.sleep(0.1)
    except WebSocketDisconnect:
        pass
    except Exception:
        try:
            await websocket.close()
        except Exception:
            pass


if __name__ == "__main__":
    # 0.0.0.0 → emülatör / aynı ağdaki telefon erişebilir
    uvicorn.run("api_server:app", host="0.0.0.0", port=8000, reload=False)
