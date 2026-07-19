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

# disconnected | connecting | device_found | device_not_worn | connected
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
    "eeg": None,
    "updated_at": None,
    "error": None,
}


def _empty_eeg(timestamp: float | None = None) -> dict[str, Any]:
    sample: dict[str, Any] = {"timestamp": timestamp or time.time()}
    for ch in CHANNELS:
        sample[ch] = 0.0
    return sample


def set_collecting(active: bool) -> None:
    with _lock:
        _state["collecting"] = active
        if not active:
            _state["error"] = None


def is_collecting() -> bool:
    with _lock:
        return bool(_state["collecting"])


def set_connecting() -> None:
    with _lock:
        _state["connection"] = "connecting"
        _state["error"] = None


def set_device_found(headset_id: str | None = None) -> None:
    with _lock:
        _state["connection"] = "device_found"
        _state["error"] = None
        if headset_id:
            _state["headset_id"] = headset_id


def set_device_not_worn(error: str | None = None) -> None:
    with _lock:
        _state["connection"] = "device_not_worn"
        _state["error"] = error or "Cihaz takılı değil — sensör teması yok"


def set_disconnected(error: str | None = None) -> None:
    """Bağlantı koptu — collecting bayrağı korunur (Durdur cihazı kesmez)."""
    with _lock:
        _state["connection"] = "disconnected"
        _state["updated_at"] = None
        _state["eeg"] = None
        if error:
            _state["error"] = error
        else:
            _state["error"] = None


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

    max_cq = max(contact.values()) if contact else 0
    worn = overall > 0 or max_cq > 0

    with _lock:
        if worn:
            _state["connection"] = "connected"
            _state["error"] = None
        else:
            _state["connection"] = "device_not_worn"
            _state["error"] = "Cihaz takılı değil — sensör teması yok"

        _state["battery_percent"] = battery_percent
        _state["signal"] = signal
        _state["battery_level"] = battery_level
        _state["contact_quality"] = contact
        _state["overall_quality"] = overall
        _state["sensor_count"] = 14
        _state["updated_at"] = time.time()


def update_from_eeg(eeg: list, timestamp: float | None = None) -> None:
    """
    Cortex EEG stream (EPOC / EPOC+ tipik kolonlar):
      [0] COUNTER
      [1] INTERPOLATED
      [2:16] AF3 … AF4 (14 kanal)
      …
    """
    ts = float(timestamp) if timestamp is not None else time.time()
    sample = _empty_eeg(ts)

    # Kanal değerleri genelde index 2'den başlar
    offset = 2 if len(eeg) >= 16 else 0
    for i, ch in enumerate(CHANNELS):
        idx = offset + i
        if idx < len(eeg):
            try:
                sample[ch] = float(eeg[idx])
            except (TypeError, ValueError):
                sample[ch] = 0.0

    with _lock:
        _state["eeg"] = sample
        _state["updated_at"] = time.time()
        # EEG paketi geldiyse cihaz en azından stream veriyor
        if _state["connection"] in ("device_found", "connecting"):
            _state["connection"] = "connected"
            _state["error"] = None


# Son Cortex paketinden bu kadar sn geçtiyse bağlantı kopmuş say
STALE_AFTER_SEC = 3.0


def snapshot() -> dict[str, Any]:
    with _lock:
        state = copy.deepcopy(_state)

    updated_at = state.get("updated_at")
    if (
        state.get("connection") in ("connected", "device_found", "device_not_worn")
        and updated_at is not None
        and (time.time() - float(updated_at)) > STALE_AFTER_SEC
    ):
        state["connection"] = "disconnected"
        state["error"] = (
            f"Cortex paketi {STALE_AFTER_SEC:.0f}s+ gelmedi "
            "(cihaz kapalı veya stream koptu)"
        )

    if state.get("eeg") is None:
        state["eeg"] = _empty_eeg(updated_at)

    return state
