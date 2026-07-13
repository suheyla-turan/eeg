"""
EEG canlı veri API'si.

Emotiv Cortex'ten gelen DEV stream'i Flutter uygulamasına sunar.
Veri toplama Flutter'dan POST /collection/start ve /collection/stop ile kontrol edilir.

Çalıştırma:
  pip install -r requirements.txt
  python api_server.py

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

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from cortex_client import CortexClient
import live_state

app = FastAPI(title="EEG Live API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

cortex = CortexClient()


@app.on_event("startup")
def on_startup():
    # Cortex otomatik başlamaz — Flutter Başlat butonu bekler
    print("API hazır. Veri toplama için POST /collection/start bekleniyor.")
    live_state.set_collecting(False)
    live_state.set_disconnected("Veri toplama başlatılmadı")


@app.on_event("shutdown")
def on_shutdown():
    cortex.stop()


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
        "collecting": state.get("collecting", False) or cortex.is_running,
        "running": cortex.is_running,
        "connection": state["connection"],
    }


@app.post("/collection/start")
def collection_start():
    """Flutter Başlat / Devam — Cortex veri toplamayı başlatır."""
    if cortex.is_running:
        return {
            "ok": True,
            "collecting": True,
            "message": "Zaten çalışıyor",
            "connection": live_state.snapshot()["connection"],
        }
    print("Flutter'dan veri toplama başlatıldı.")
    cortex.start_background()
    return {
        "ok": True,
        "collecting": True,
        "message": "Veri toplama başladı",
        "connection": live_state.snapshot()["connection"],
    }


@app.post("/collection/stop")
def collection_stop():
    """Flutter Durdur — Cortex bağlantısını keser, veri almayı durdurur."""
    print("Flutter'dan veri toplama durduruldu.")
    cortex.stop()
    live_state.set_disconnected("Flutter tarafından durduruldu")
    return {
        "ok": True,
        "collecting": False,
        "message": "Veri toplama durduruldu",
        "connection": "disconnected",
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
