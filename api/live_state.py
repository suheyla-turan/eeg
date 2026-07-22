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
    # Gerçek spektral bantlar (pow lisansı gerekmez — ham EEG Welch PSD)
    "band_power": {
        "delta": 0.0,
        "theta": 0.0,
        "alpha": 0.0,
        "beta": 0.0,
        "gamma": 0.0,
    },
    # Göreli bant güçleri (toplam = 1); bilişsel metrikler için tercih edilir
    "relative_band_power": {
        "delta": 0.0,
        "theta": 0.0,
        "alpha": 0.0,
        "beta": 0.0,
        "gamma": 0.0,
    },
    # Bölgesel mutlak bant güçleri (frontal / temporal / …)
    "region_band_power": {},
    "eeg": None,
    # Cortex EEG / POW abonelik durumu
    "eeg_subscribed": False,
    "pow_subscribed": False,
    "eeg_stream_active": False,
    "spectral_source": "none",  # welch | pow | none
    "pow_cols": [],
    "last_eeg_at": None,
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
        _state["band_power"] = {
            "delta": 0.0,
            "theta": 0.0,
            "alpha": 0.0,
            "beta": 0.0,
            "gamma": 0.0,
        }
        _state["relative_band_power"] = {
            "delta": 0.0,
            "theta": 0.0,
            "alpha": 0.0,
            "beta": 0.0,
            "gamma": 0.0,
        }
        _state["region_band_power"] = {}
        _state["eeg_subscribed"] = False
        _state["pow_subscribed"] = False
        _state["eeg_stream_active"] = False
        _state["spectral_source"] = "none"
        _state["pow_cols"] = []
        _state["last_eeg_at"] = None
        if error:
            _state["error"] = error
        else:
            _state["error"] = None
    try:
        from spectral import reset_spectral_buffer

        reset_spectral_buffer()
    except Exception:
        pass


def set_connected() -> None:
    with _lock:
        _state["connection"] = "connected"
        _state["error"] = None


def set_eeg_subscribed(active: bool) -> None:
    with _lock:
        _state["eeg_subscribed"] = bool(active)
        if not active and not _state.get("pow_subscribed"):
            _state["eeg_stream_active"] = False


def set_pow_subscribed(active: bool, cols: list | None = None) -> None:
    with _lock:
        _state["pow_subscribed"] = bool(active)
        if cols:
            _state["pow_cols"] = list(cols)
        if not active and not _state.get("eeg_subscribed"):
            _state["eeg_stream_active"] = False


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

    # Overall yoksa (yalnızca 14 kanal) kanal CQ medyanından türet.
    # Aksi halde overall=0 kalır ve mobil kalite kapısı tüm örnekleri ezer.
    if overall <= 0 and contact:
        vals = sorted(contact.values())
        overall = vals[len(vals) // 2]

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
    # Döngüsel import kaçınmak için burada alınır
    from spectral import (
        current_region_band_power,
        current_relative_band_power,
        push_eeg_sample,
    )

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

    # Spektral hesaplama yalnızca ham EEG'den (DEV/CQ kullanılmaz)
    bands = push_eeg_sample(sample, timestamp=ts)
    relative = current_relative_band_power()
    regions = current_region_band_power()

    now = time.time()
    with _lock:
        _state["eeg"] = sample
        _state["band_power"] = bands
        _state["relative_band_power"] = relative
        _state["region_band_power"] = regions
        _state["eeg_subscribed"] = True
        _state["eeg_stream_active"] = True
        _state["spectral_source"] = "welch"
        _state["last_eeg_at"] = now
        _state["updated_at"] = now
        # EEG paketi geldiyse cihaz en azından stream veriyor
        if _state["connection"] in ("device_found", "connecting", "device_not_worn"):
            # Ham EEG geliyorsa deney için bağlı say
            _state["connection"] = "connected"
            _state["error"] = None


def update_from_pow(pow_values: list, timestamp: float | None = None) -> None:
    """
    Emotiv POW stream — kanal bazlı bant güçleri (uV²/Hz).
    Ham EEG lisansı yoksa spektral kaynak olarak kullanılır.
    Etiketler: SENSOR/theta|alpha|betaL|betaH|gamma
    """
    with _lock:
        cols = list(_state.get("pow_cols") or [])

    if not cols or not pow_values:
        return

    sums = {"delta": 0.0, "theta": 0.0, "alpha": 0.0, "beta": 0.0, "gamma": 0.0}
    counts = {"delta": 0, "theta": 0, "alpha": 0, "beta": 0, "gamma": 0}
    # Bölgesel birikim
    region_sums: dict[str, dict[str, float]] = {}
    region_counts: dict[str, dict[str, int]] = {}

    from spectral import REGIONS

    channel_to_regions: dict[str, list[str]] = {}
    for region, chans in REGIONS.items():
        for ch in chans:
            channel_to_regions.setdefault(ch, []).append(region)

    n = min(len(cols), len(pow_values))
    for i in range(n):
        label = str(cols[i])
        if "/" not in label:
            continue
        sensor, band = label.split("/", 1)
        try:
            val = float(pow_values[i])
        except (TypeError, ValueError):
            continue
        if val < 0 or val != val:  # NaN
            continue

        key = None
        if band == "theta":
            key = "theta"
        elif band == "alpha":
            key = "alpha"
        elif band in ("betaL", "betaH", "beta"):
            key = "beta"
        elif band == "gamma":
            key = "gamma"
        elif band == "delta":
            key = "delta"
        if key is None:
            continue

        sums[key] += val
        counts[key] += 1
        for region in channel_to_regions.get(sensor, []):
            region_sums.setdefault(region, {k: 0.0 for k in sums})
            region_counts.setdefault(region, {k: 0 for k in sums})
            region_sums[region][key] += val
            region_counts[region][key] += 1

    bands = {}
    for k in sums:
        bands[k] = (sums[k] / counts[k]) if counts[k] else 0.0

    total = sum(bands.values())
    relative = (
        {k: bands[k] / total for k in bands}
        if total > 1e-18
        else {k: 0.0 for k in bands}
    )

    regions_out: dict[str, dict[str, float]] = {}
    for region, rsum in region_sums.items():
        rc = region_counts[region]
        regions_out[region] = {
            k: (rsum[k] / rc[k]) if rc[k] else 0.0 for k in rsum
        }

    now = time.time()
    with _lock:
        # Ham EEG Welch varsa onu koru; yoksa POW kullan
        if _state.get("spectral_source") == "welch" and _state.get(
            "eeg_stream_active"
        ):
            _state["updated_at"] = now
            return

        _state["band_power"] = bands
        _state["relative_band_power"] = relative
        _state["region_band_power"] = regions_out
        _state["pow_subscribed"] = True
        _state["eeg_stream_active"] = True  # spektral veri akıyor
        _state["spectral_source"] = "pow"
        _state["last_eeg_at"] = now
        _state["updated_at"] = now
        if _state["connection"] in ("device_found", "connecting", "device_not_worn"):
            _state["connection"] = "connected"
            _state["error"] = None


# Son Cortex paketinden bu kadar sn geçtiyse bağlantı kopmuş say
STALE_AFTER_SEC = 3.0
EEG_STALE_SEC = 2.0


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

    last_eeg = state.get("last_eeg_at")
    if last_eeg is None or (time.time() - float(last_eeg)) > EEG_STALE_SEC:
        state["eeg_stream_active"] = False

    # Spektral özet bayrağı (Flutter deney öncesi kontrol)
    bp = state.get("band_power") or {}
    try:
        state["has_spectral"] = float(sum(float(bp.get(k, 0) or 0) for k in bp)) > 1e-12
    except (TypeError, ValueError):
        state["has_spectral"] = False

    if state.get("eeg") is None:
        state["eeg"] = _empty_eeg(updated_at)

    return state
