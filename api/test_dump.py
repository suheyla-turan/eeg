"""Test oturumu: reel / metin EEG örneklerini ayrı dosyalara yazar.

Çıktı klasörü: <repo>/_export/test_run/
  eeg_reels.ndjson  — her satır bir örnek (reels)
  eeg_text.ndjson   — her satır bir örnek (text)
  eeg_reels.json    — finalize sonrası tam liste
  eeg_text.json     — finalize sonrası tam liste
  meta.json         — sayaçlar / zaman damgaları
"""

from __future__ import annotations

import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_LOCK = threading.Lock()

_ROOT = Path(__file__).resolve().parent.parent / "_export" / "test_run"
_REELS_NDJSON = _ROOT / "eeg_reels.ndjson"
_TEXT_NDJSON = _ROOT / "eeg_text.ndjson"
_REELS_JSON = _ROOT / "eeg_reels.json"
_TEXT_JSON = _ROOT / "eeg_text.json"
_META = _ROOT / "meta.json"

_counts = {"reels": 0, "text": 0, "other": 0}
_started_at: str | None = None


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ensure_dir() -> None:
    _ROOT.mkdir(parents=True, exist_ok=True)


def _write_meta() -> None:
    payload = {
        "startedAt": _started_at,
        "updatedAt": _utc_now(),
        "counts": dict(_counts),
        "paths": {
            "reelsNdjson": str(_REELS_NDJSON),
            "textNdjson": str(_TEXT_NDJSON),
            "reelsJson": str(_REELS_JSON),
            "textJson": str(_TEXT_JSON),
        },
    }
    _META.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def reset() -> dict[str, Any]:
    """Yeni test için dosyaları temizler."""
    global _started_at
    with _LOCK:
        _ensure_dir()
        for path in (_REELS_NDJSON, _TEXT_NDJSON, _REELS_JSON, _TEXT_JSON, _META):
            if path.exists():
                path.unlink()
        _counts["reels"] = 0
        _counts["text"] = 0
        _counts["other"] = 0
        _started_at = _utc_now()
        _write_meta()
        print(f"[test_dump] reset -> {_ROOT}")
        return status()


def append_sample(sample: dict[str, Any]) -> dict[str, Any]:
    """Tek örneği phase'e göre NDJSON'a ekler."""
    global _started_at
    phase = str(sample.get("phase") or "other").strip().lower()
    if phase in ("reels", "reel", "video"):
        key = "reels"
        path = _REELS_NDJSON
    elif phase in ("text", "metin", "reading", "metinler"):
        key = "text"
        path = _TEXT_NDJSON
    else:
        key = "other"
        path = _ROOT / f"eeg_{phase or 'other'}.ndjson"

    with _LOCK:
        _ensure_dir()
        if _started_at is None:
            _started_at = _utc_now()
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(sample, ensure_ascii=False) + "\n")
        _counts[key] = _counts.get(key, 0) + 1
        if _counts["reels"] + _counts["text"] + _counts.get("other", 0) <= 3 or (
            _counts[key] % 20 == 0
        ):
            print(f"[test_dump] +1 {key} (reels={_counts['reels']} text={_counts['text']})")
        _write_meta()
        return status()


def finalize(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    """NDJSON'ları JSON listelerine çevirir; isteğe bağlı tam payload yazar."""
    with _LOCK:
        _ensure_dir()
        reels = _read_ndjson(_REELS_NDJSON)
        text = _read_ndjson(_TEXT_NDJSON)

        if payload:
            samples = payload.get("samples") or []
            if isinstance(samples, list) and samples:
                reels = [s for s in samples if str(s.get("phase", "")).lower() in ("reels", "reel", "video")]
                text = [s for s in samples if str(s.get("phase", "")).lower() in ("text", "metin", "reading", "metinler")]

        _REELS_JSON.write_text(
            json.dumps(
                {
                    "phase": "reels",
                    "sampleCount": len(reels),
                    "exportedAt": _utc_now(),
                    "meta": (payload or {}).get("meta"),
                    "experimentId": (payload or {}).get("experimentId"),
                    "participantId": (payload or {}).get("participantId"),
                    "samples": reels,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        _TEXT_JSON.write_text(
            json.dumps(
                {
                    "phase": "text",
                    "sampleCount": len(text),
                    "exportedAt": _utc_now(),
                    "meta": (payload or {}).get("meta"),
                    "experimentId": (payload or {}).get("experimentId"),
                    "participantId": (payload or {}).get("participantId"),
                    "samples": text,
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        _counts["reels"] = len(reels)
        _counts["text"] = len(text)
        _write_meta()
        print(
            f"[test_dump] finalize reels={len(reels)} text={len(text)} -> {_ROOT}"
        )
        return status()


def _read_ndjson(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    out: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            if isinstance(obj, dict):
                out.append(obj)
        except json.JSONDecodeError:
            continue
    return out


def status() -> dict[str, Any]:
    return {
        "ok": True,
        "startedAt": _started_at,
        "counts": dict(_counts),
        "dir": str(_ROOT),
        "files": {
            "reelsNdjson": str(_REELS_NDJSON),
            "textNdjson": str(_TEXT_NDJSON),
            "reelsJson": str(_REELS_JSON),
            "textJson": str(_TEXT_JSON),
            "meta": str(_META),
        },
    }
