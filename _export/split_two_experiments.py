import json, csv, shutil
from datetime import datetime
from pathlib import Path

out_root = Path(r"c:\Users\msi\Desktop\eeg\_export\deneyler")
desk_root = Path(r"c:\Users\msi\Desktop\EEG_Deneyler")
desk_root.mkdir(parents=True, exist_ok=True)

CHANNELS = ["AF3", "F7", "F3", "FC5", "T7", "P7", "O1", "O2", "P8", "T8", "FC6", "F4", "F8", "AF4"]
BANDS = ["delta", "theta", "alpha", "beta", "gamma"]
REGIONS = ["frontal", "attention_frontal", "temporal", "parietal", "occipital"]

meta_info = {
    1: {
        "label": "Birinci Deney",
        "code": "P-0001",
        "participantName": "Suheyla Melike Turan",
        "experimentId": "hWsVhdI9oQJZ6biX44HZ",
        "participantId": "o1FLTILhd7QBhncxZWrM",
    },
    2: {
        "label": "Ikinci Deney",
        "code": "P-0003",
        "participantName": "Yucel Yilmaz",
        "experimentId": "2OaWigHnVBS6va0OCwkA",
        "participantId": "OSsMRC0eiKu0N3afMJML",
    },
}


def num(v, default=0.0):
    try:
        if v is None:
            return default
        return float(v)
    except Exception:
        return default


def duration_sec(arr):
    if len(arr) < 2:
        return None
    try:
        t0 = datetime.fromisoformat(str(arr[0]["capturedAt"]).replace("Z", "+00:00"))
        t1 = datetime.fromisoformat(str(arr[-1]["capturedAt"]).replace("Z", "+00:00"))
        return round((t1 - t0).total_seconds(), 1)
    except Exception:
        return None


def flatten_raw_row(s):
    eeg = s.get("eeg") if isinstance(s.get("eeg"), dict) else {}
    bp = s.get("bandPower") if isinstance(s.get("bandPower"), dict) else {}
    rbp = s.get("relativeBandPower") if isinstance(s.get("relativeBandPower"), dict) else {}
    rbp_reg = s.get("regionBandPower") if isinstance(s.get("regionBandPower"), dict) else {}
    cq = s.get("contactQuality") if isinstance(s.get("contactQuality"), dict) else {}
    row = {
        "capturedAt": s.get("capturedAt") or "",
        "phase": s.get("phase") or "",
        "timestamp": s.get("timestamp") if s.get("timestamp") is not None else (eeg.get("timestamp") or ""),
        "connection": s.get("connection") or "",
        "collecting": bool(s.get("collecting")),
        "batteryPercent": num(s.get("batteryPercent")),
        "sensorCount": num(s.get("sensorCount")),
        "signal": num(s.get("signal")),
        "overallQuality": num(s.get("overallQuality")),
    }
    for b in BANDS:
        row[f"bp_{b}"] = num(bp.get(b))
        row[f"rbp_{b}"] = num(rbp.get(b))
    for region in REGIONS:
        rb = rbp_reg.get(region) if isinstance(rbp_reg.get(region), dict) else {}
        for b in BANDS:
            row[f"region_{region}_{b}"] = num(rb.get(b))
    for ch in CHANNELS:
        row[f"ch_{ch}"] = num(eeg.get(ch))
        if cq:
            row[f"cq_{ch}"] = num(cq.get(ch))
    return row


def write_csv(path, rows):
    if not rows:
        return
    keys = list(rows[0].keys())
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)


summary = []
for n, info in meta_info.items():
    src = out_root / f"deney{n}_raw.json"
    with open(src, encoding="utf-8") as f:
        data = json.load(f)
    samples = data.get("samples") or []
    phases = {}
    for s in samples:
        p = str(s.get("phase") or "unknown").lower()
        if p in ("reel", "video"):
            p = "reels"
        if p in ("metin", "reading", "metinler"):
            p = "text"
        phases.setdefault(p, []).append(s)

    den_dir = out_root / f"deney{n}"
    desk_dir = desk_root / f"deney{n}_{info['code']}"
    den_dir.mkdir(parents=True, exist_ok=True)
    desk_dir.mkdir(parents=True, exist_ok=True)

    shutil.copy2(src, den_dir / "eeg_full_raw.json")
    shutil.copy2(src, desk_dir / "eeg_full_raw.json")

    exp_meta = {
        "deneyNo": n,
        "label": info["label"],
        "participantCode": info["code"],
        "participantName": info["participantName"],
        "experimentId": data.get("experimentId") or info["experimentId"],
        "participantId": data.get("participantId") or info["participantId"],
        "exportedAt": data.get("exportedAt"),
        "sampleCountTotal": len(samples),
        "phases": {k: len(v) for k, v in phases.items()},
        "note": "Ham EEG kaydi; hesaplanmis skor yok. reels=video, text=metin.",
    }

    for phase, label_tr in (("reels", "reels"), ("text", "metin")):
        arr = phases.get(phase) or []
        payload = {
            **exp_meta,
            "phase": phase,
            "phaseLabel": label_tr,
            "sampleCount": len(arr),
            "durationSec": duration_sec(arr),
            "firstCapturedAt": arr[0].get("capturedAt") if arr else None,
            "lastCapturedAt": arr[-1].get("capturedAt") if arr else None,
            "samples": arr,
        }
        jname = f"eeg_{label_tr}_ham.json"
        cname = f"eeg_{label_tr}_ham.csv"
        for d in (den_dir, desk_dir):
            with open(d / jname, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            write_csv(d / cname, [flatten_raw_row(s) for s in arr])
        summary.append(
            {
                "deney": n,
                "label": info["label"],
                "code": info["code"],
                "phase": label_tr,
                "samples": len(arr),
                "durationSec": payload["durationSec"],
                "folder": str(desk_dir),
            }
        )

    with open(den_dir / "meta.json", "w", encoding="utf-8") as f:
        json.dump(exp_meta, f, ensure_ascii=False, indent=2)
    with open(desk_dir / "meta.json", "w", encoding="utf-8") as f:
        json.dump(exp_meta, f, ensure_ascii=False, indent=2)

    print(f"=== Deney {n} ({info['label']}) {info['code']} {info['participantName']} ===")
    print(f"  experimentId={exp_meta['experimentId']} total={len(samples)}")
    for phase in ("reels", "text"):
        arr = phases.get(phase) or []
        print(f"  {phase}: n={len(arr)} dur={duration_sec(arr)}")
    print(f"  Desktop: {desk_dir}")

print("\nOZET:")
for s in summary:
    print(
        f"  Deney{s['deney']} {s['code']} {s['phase']}: "
        f"{s['samples']} ornek, {s['durationSec']} sn"
    )
