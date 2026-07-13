"""Mobil uygulamanın okuduğu anlık EEG durumu."""

from __future__ import annotations

import copy
import threading
import time
from typing import Any

CHANNELS = [
    "AF3",
    "F7",
    "F3",
    "FC5",
    "T7",
    "P7",
    "O1",
    "O2",
    "P8",
    "T8",
    "FC6",
    "F4",
    "F8",
    "AF4",
]

_lock = threading.Lock()

_state: dict[str, Any] = {
    "connection": "disconnected",
    "collecting": False,
    "battery_percent": 0,
    "battery_level": 0,
    "signal": 0.0,
    "sensor_count": 14,
    "contact_quality": {ch: 0 for ch in CHANNELS},
    "overall_quality": 0,
    "updated_at": None,
    "error": None,
}


def set_collecting(active: bool) -> None:
    with _lock:
        _state["collecting"] = active
        if not active:
            _state["error"] = None


def set_connecting() -> None:
    with _lock:
        _state["connection"] = "connecting"
        _state["error"] = None


def set_disconnected(error: str | None = None) -> None:
    with _lock:
        _state["connection"] = "disconnected"
        _state["updated_at"] = None
        if error:
            _state["error"] = error


def set_connected() -> None:
    with _lock:
        _state["connection"] = "connected"
        _state["error"] = None


def update_from_dev(dev: list) -> None:
    """
    Cortex DEV stream:
      [0] battery level (0-4)
      [1] signal quality
      [2] contact quality list (14 + overall)
      [3] battery percent
    Contact quality: 0=yok, 1=çok zayıf, 2=zayıf, 3=orta, 4=iyi
    """
    battery_level = int(dev[0]) if len(dev) > 0 else 0
    signal = float(dev[1]) if len(dev) > 1 else 0.0
    sensors = list(dev[2]) if len(dev) > 2 else []
    battery_percent = int(dev[3]) if len(dev) > 3 else 0

    contact = {ch: 0 for ch in CHANNELS}
    overall = 0

    for i, ch in enumerate(CHANNELS):
        if i < len(sensors):
            contact[ch] = int(sensors[i])

    if len(sensors) > 14:
        overall = int(sensors[14])

    with _lock:
        _state["connection"] = "connected"
        _state["battery_percent"] = battery_percent
        _state["signal"] = signal
        _state["battery_level"] = battery_level
        _state["contact_quality"] = contact
        _state["overall_quality"] = overall
        _state["sensor_count"] = 14
        _state["updated_at"] = time.time()
        _state["error"] = None


# Son Cortex paketinden bu kadar sn geçtiyse bağlantı kopmuş say
STALE_AFTER_SEC = 3.0


def snapshot() -> dict[str, Any]:
    with _lock:
        state = copy.deepcopy(_state)

    updated_at = state.get("updated_at")
    if (
        state.get("connection") == "connected"
        and updated_at is not None
        and (time.time() - float(updated_at)) > STALE_AFTER_SEC
    ):
        state["connection"] = "disconnected"
        state["error"] = (
            f"Cortex paketi {STALE_AFTER_SEC:.0f}s+ gelmedi "
            "(cihaz kapalı veya stream koptu)"
        )

    return state
