"""Ham EEG → kalite/artefakt → filtre → Welch PSD → bant güçleri.

Pipeline (yalnızca spektral katman; DEV/contact quality buraya GİRMEZ):

  Ham EEG
    → Artefakt reddi (kanal düz/aşırı genlik)
    → Bandpass 0.5–45 Hz (FFT mask)
    → Notch 50 Hz (şebeke)
    → Welch PSD (Hann, %50 overlap, ortalama)
    → Mutlak / göreli bant güçleri
    → Bölgesel ortalama (frontal / temporal / parietal / occipital)

Referanslar:
  - Welch (1967): averaged modified periodograms
  - Klimesch (1999): alpha/theta band definitions in cognitive EEG
  - Pope et al. (1995): engagement index (β/(α+θ)) — Flutter tarafında kullanılır
"""

from __future__ import annotations

from collections import deque
from typing import Any

import numpy as np

from live_state import CHANNELS

DEFAULT_FS = 128.0
WINDOW_SEC = 2.0
MIN_SAMPLES = 64

# Standart EEG bantları (Hz)
BANDS = {
    "delta": (0.5, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 13.0),
    "beta": (13.0, 30.0),
    "gamma": (30.0, 45.0),
}

# Emotiv EPOC anatomik gruplar
REGIONS: dict[str, list[str]] = {
    "frontal": ["AF3", "F7", "F3", "FC5", "FC6", "F4", "F8", "AF4"],
    "attention_frontal": ["AF3", "F3", "F4", "AF4"],
    "temporal": ["T7", "T8"],
    "parietal": ["P7", "P8"],
    "occipital": ["O1", "O2"],
}

BANDPASS = (0.5, 45.0)
NOTCH_HZ = 50.0
NOTCH_WIDTH = 2.0


def _empty_bands() -> dict[str, float]:
    return {name: 0.0 for name in BANDS}


def _empty_regions() -> dict[str, dict[str, float]]:
    return {region: _empty_bands() for region in REGIONS}


class EegSpectralBuffer:
    def __init__(self, window_sec: float = WINDOW_SEC, fs_hint: float = DEFAULT_FS):
        self._maxlen = max(MIN_SAMPLES, int(window_sec * fs_hint * 1.5))
        self._times: deque[float] = deque(maxlen=self._maxlen)
        self._channels: dict[str, deque[float]] = {
            ch: deque(maxlen=self._maxlen) for ch in CHANNELS
        }
        self._last_bands: dict[str, float] = _empty_bands()
        self._last_relative: dict[str, float] = _empty_bands()
        self._last_regions: dict[str, dict[str, float]] = _empty_regions()
        self._push_count = 0

    def clear(self) -> None:
        self._times.clear()
        for q in self._channels.values():
            q.clear()
        self._last_bands = _empty_bands()
        self._last_relative = _empty_bands()
        self._last_regions = _empty_regions()
        self._push_count = 0

    def push(self, sample: dict[str, Any], timestamp: float | None = None) -> dict[str, float]:
        ts = float(timestamp if timestamp is not None else sample.get("timestamp") or 0.0)
        self._times.append(ts)
        for ch in CHANNELS:
            try:
                self._channels[ch].append(float(sample.get(ch, 0.0) or 0.0))
            except (TypeError, ValueError):
                self._channels[ch].append(0.0)

        self._push_count += 1
        if self._push_count % 8 == 0 or len(self._times) == MIN_SAMPLES:
            self._recompute()
        return dict(self._last_bands)

    def compute(self) -> dict[str, float]:
        self._recompute()
        return dict(self._last_bands)

    def _recompute(self) -> None:
        n = len(self._times)
        if n < MIN_SAMPLES:
            return

        fs = self._estimate_fs()
        if fs < 16.0:
            self._last_bands = _empty_bands()
            self._last_relative = _empty_bands()
            self._last_regions = _empty_regions()
            return

        per_ch: dict[str, dict[str, float]] = {}
        for ch in CHANNELS:
            arr = np.asarray(self._channels[ch], dtype=np.float64)
            if arr.size < MIN_SAMPLES:
                continue
            if _is_artifact(arr):
                continue
            cleaned = _bandpass_notch(arr, fs)
            bp = _band_powers_welch(cleaned, fs)
            if sum(bp.values()) <= 0:
                continue
            per_ch[ch] = bp

        if not per_ch:
            self._last_bands = _empty_bands()
            self._last_relative = _empty_bands()
            self._last_regions = _empty_regions()
            return

        # Global: tüm geçerli kanalların ortalaması
        global_abs = _average_bands(list(per_ch.values()))
        self._last_bands = global_abs
        self._last_relative = _relative_bands(global_abs)

        # Bölgesel ortalamalar
        regions: dict[str, dict[str, float]] = {}
        for region, chans in REGIONS.items():
            vals = [per_ch[c] for c in chans if c in per_ch]
            regions[region] = _average_bands(vals) if vals else _empty_bands()
        self._last_regions = regions

    def _estimate_fs(self) -> float:
        if len(self._times) < 2:
            return DEFAULT_FS
        t0 = self._times[0]
        t1 = self._times[-1]
        dt = t1 - t0
        if dt <= 0:
            return DEFAULT_FS
        return (len(self._times) - 1) / dt


def _is_artifact(x: np.ndarray) -> bool:
    """Düz çizgi veya aşırı genlik (göz kırpma / hareket) reddi."""
    if x.size < 8:
        return True
    std = float(np.std(x))
    if std < 1e-6:
        return True  # flatline
    # Emotiv µV aralığı tipik < ~200; aşırı sapma artefakt
    if std > 500.0 or float(np.max(np.abs(x - np.mean(x)))) > 1500.0:
        return True
    return False


def _bandpass_notch(
    x: np.ndarray,
    fs: float,
    low: float = BANDPASS[0],
    high: float = BANDPASS[1],
    notch: float = NOTCH_HZ,
    notch_width: float = NOTCH_WIDTH,
) -> np.ndarray:
    """FFT-domain bandpass + notch (scipy gerekmez)."""
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    n = x.size
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, d=1.0 / fs)

    keep = (freqs >= low) & (freqs <= min(high, fs / 2.0 - 1e-9))
    if notch < fs / 2.0:
        half = notch_width / 2.0
        keep &= ~((freqs >= notch - half) & (freqs <= notch + half))

    spectrum[~keep] = 0.0
    return np.fft.irfft(spectrum, n=n)


def _welch_psd(
    x: np.ndarray,
    fs: float,
    nperseg: int | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Welch ortalama PSD.
    Hann pencere, %50 örtüşme — Welch (1967).
    """
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    n = x.size
    if n < 16:
        return np.zeros(1), np.zeros(1)

    if nperseg is None:
        # ~1 sn segment veya mevcut uzunluğun yarısı
        nperseg = int(min(max(32, fs), n // 2))
        nperseg = max(32, min(nperseg, n))
    # Çift uzunluk (Hann simetrisi)
    if nperseg % 2 == 1:
        nperseg -= 1
    nperseg = max(32, nperseg)
    if n < nperseg:
        nperseg = n if n % 2 == 0 else n - 1
        if nperseg < 16:
            return np.zeros(1), np.zeros(1)

    noverlap = nperseg // 2
    step = nperseg - noverlap
    window = np.hanning(nperseg)
    win_power = float(np.sum(window**2))
    if win_power <= 0:
        return np.zeros(1), np.zeros(1)

    segments: list[np.ndarray] = []
    for start in range(0, n - nperseg + 1, step):
        seg = x[start : start + nperseg] * window
        spectrum = np.fft.rfft(seg)
        psd = (np.abs(spectrum) ** 2) / (fs * win_power)
        segments.append(psd)

    if not segments:
        # Tek pencere fallback
        window_full = np.hanning(n)
        spectrum = np.fft.rfft(x * window_full)
        psd = (np.abs(spectrum) ** 2) / (fs * np.sum(window_full**2))
        freqs = np.fft.rfftfreq(n, d=1.0 / fs)
        return psd, freqs

    mean_psd = np.mean(np.stack(segments, axis=0), axis=0)
    freqs = np.fft.rfftfreq(nperseg, d=1.0 / fs)
    return mean_psd, freqs


def _band_powers_welch(x: np.ndarray, fs: float) -> dict[str, float]:
    if np.allclose(x, 0):
        return _empty_bands()

    psd, freqs = _welch_psd(x, fs)
    if psd.size < 2 or freqs.size < 2:
        return _empty_bands()

    out: dict[str, float] = {}
    for name, (lo, hi) in BANDS.items():
        hi_eff = min(hi, fs / 2.0)
        mask = (freqs >= lo) & (freqs < hi_eff)
        out[name] = float(np.sum(psd[mask])) if np.any(mask) else 0.0
    return out


def _average_bands(items: list[dict[str, float]]) -> dict[str, float]:
    if not items:
        return _empty_bands()
    out = _empty_bands()
    for name in BANDS:
        out[name] = float(sum(b.get(name, 0.0) for b in items) / len(items))
    return out


def _relative_bands(absolute: dict[str, float]) -> dict[str, float]:
    total = sum(absolute.values())
    if total <= 1e-18:
        return _empty_bands()
    return {name: absolute[name] / total for name in BANDS}


# Modül düzeyinde tek tampon — Cortex dinleyicisi besler
_buffer = EegSpectralBuffer()


def reset_spectral_buffer() -> None:
    _buffer.clear()


def push_eeg_sample(sample: dict[str, Any], timestamp: float | None = None) -> dict[str, float]:
    return _buffer.push(sample, timestamp=timestamp)


def current_band_power() -> dict[str, float]:
    return dict(_buffer._last_bands)


def current_relative_band_power() -> dict[str, float]:
    return dict(_buffer._last_relative)


def current_region_band_power() -> dict[str, dict[str, float]]:
    return {k: dict(v) for k, v in _buffer._last_regions.items()}
