import asyncio
import json
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(title="EEG AI Backend", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

EMOTION_LABELS = {
    "mutluluk": "Mutluluk",
    "ofke": "Öfke",
    "uyku": "Uyku Hali",
    "stres": "Stres",
    "odak": "Odak",
    "uzuntu": "Üzüntü",
    "sakinlik": "Sakinlik",
}


class EEGPayload(BaseModel):
    channels: list[float] = Field(default_factory=list)
    timestamp: str | None = None
    raw: dict[str, Any] | None = None


class DeviceStatusPayload(BaseModel):
    connected: bool
    headset_id: str | None = None
    session_id: str | None = None
    message: str | None = None


class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict[str, Any]) -> None:
        dead_connections: list[WebSocket] = []
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                dead_connections.append(connection)

        for connection in dead_connections:
            self.disconnect(connection)


manager = ConnectionManager()

state: dict[str, Any] = {
    "device": {
        "connected": False,
        "headset_id": None,
        "session_id": None,
        "message": "Cihaz bağlı değil",
    },
    "latest_eeg": None,
    "emotions": {
        key: {
            "label": label,
            "score": None,
            "status": "pending_ai",
        }
        for key, label in EMOTION_LABELS.items()
    },
    "updated_at": None,
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def build_snapshot() -> dict[str, Any]:
    return {
        "device": state["device"],
        "latest_eeg": state["latest_eeg"],
        "emotions": state["emotions"],
        "updated_at": state["updated_at"],
    }


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/status")
async def get_status() -> dict[str, Any]:
    return build_snapshot()


@app.post("/api/device/status")
async def update_device_status(payload: DeviceStatusPayload) -> dict[str, Any]:
    state["device"] = payload.model_dump()
    state["updated_at"] = utc_now()

    message = {
        "type": "device_status",
        "data": state["device"],
        "updated_at": state["updated_at"],
    }
    await manager.broadcast(message)
    return {"ok": True}


@app.post("/api/eeg")
async def ingest_eeg(payload: EEGPayload) -> dict[str, Any]:
    timestamp = payload.timestamp or utc_now()

    state["latest_eeg"] = {
        "channels": payload.channels,
        "timestamp": timestamp,
        "channel_count": len(payload.channels),
        "raw": payload.raw,
    }
    state["updated_at"] = timestamp

    message = {
        "type": "eeg_update",
        "data": state["latest_eeg"],
        "updated_at": state["updated_at"],
    }
    await manager.broadcast(message)
    return {"ok": True}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await manager.connect(websocket)

    try:
        await websocket.send_json(
            {
                "type": "snapshot",
                "data": build_snapshot(),
                "updated_at": state["updated_at"],
            }
        )

        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
