import json, csv, os
from datetime import datetime

path = r"c:\Users\msi\Desktop\eeg\_export\eeg_raw.json"
out_dir = r"c:\Users\msi\Desktop\eeg\_export"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

samples = data.get("samples") or []
print(f"total_samples={len(samples)}")
print(f"experimentId={data.get('experimentId')}")
print(f"participantId={data.get('participantId')}")

phases = {}
for s in samples:
    p = s.get("phase") or "unknown"
    phases.setdefault(p, []).append(s)

for p, arr in phases.items():
    print(f"phase={p} n={len(arr)}")
    if arr:
        print(f"  first={arr[0].get('capturedAt')} last={arr[-1].get('capturedAt')}")

# Inspect one sample keys
if samples:
    s0 = samples[0]
    print("top_keys=", sorted(s0.keys()))
    eeg = s0.get("eeg") or {}
    print("eeg_keys=", sorted(eeg.keys()) if isinstance(eeg, dict) else type(eeg))
    bp = s0.get("bandPower") or {}
    rbp = s0.get("relativeBandPower") or {}
    print("bandPower_keys=", sorted(bp.keys()) if isinstance(bp, dict) else type(bp))
    print("relativeBandPower_keys=", sorted(rbp.keys()) if isinstance(rbp, dict) else type(rbp))
    print("sample0_eeg=", {k: eeg.get(k) for k in list(eeg)[:20]} if isinstance(eeg, dict) else None)

def num(v, default=0.0):
    try:
        if v is None: return default
        return float(v)
    except Exception:
        return default

def flatten_bands(prefix, bands):
    out = {}
    if not isinstance(bands, dict):
        return out
    for k, v in bands.items():
        if isinstance(v, dict):
            for k2, v2 in v.items():
                out[f"{prefix}_{k}_{k2}"] = num(v2)
        else:
            out[f"{prefix}_{k}"] = num(v)
    return out

def row_from_sample(s):
    eeg = s.get("eeg") if isinstance(s.get("eeg"), dict) else {}
    bp = s.get("bandPower") if isinstance(s.get("bandPower"), dict) else {}
    rbp = s.get("relativeBandPower") if isinstance(s.get("relativeBandPower"), dict) else {}
    row = {
        "capturedAt": s.get("capturedAt") or "",
        "phase": s.get("phase") or "",
        "signal": num(s.get("signal")),
        "overallQuality": num(s.get("overallQuality")),
        "batteryPercent": num(s.get("batteryPercent")),
        "connection": s.get("connection") or "",
        "collecting": bool(s.get("collecting")),
        # cognitive / emotiv metrics from eeg sample
        "attention": num(eeg.get("attention", eeg.get("Attention"))),
        "focus": num(eeg.get("focus", eeg.get("Focus"))),
        "engagement": num(eeg.get("engagement", eeg.get("Engagement"))),
        "stress": num(eeg.get("stress", eeg.get("Stress"))),
        "relaxation": num(eeg.get("relaxation", eeg.get("Relaxation"))),
        "interest": num(eeg.get("interest", eeg.get("Interest"))),
        "excitement": num(eeg.get("excitement", eeg.get("Excitement"))),
        "mentalFatigue": num(eeg.get("mentalFatigue", eeg.get("MentalFatigue"))),
        "distraction": num(eeg.get("distraction", eeg.get("Distraction"))),
        "timestamp": eeg.get("timestamp") or s.get("timestamp") or "",
    }
    # common band names
    for name, src in (("bp", bp), ("rbp", rbp)):
        for band in ("delta", "theta", "alpha", "beta", "gamma"):
            row[f"{name}_{band}"] = num(src.get(band))
    # also flatten nested if present
    row.update(flatten_bands("bp", bp))
    row.update(flatten_bands("rbp", rbp))
    # keep any extra flat eeg numeric fields
    for k, v in eeg.items():
        if isinstance(v, (int, float)) and k not in row:
            row[f"eeg_{k}"] = float(v)
    return row

def write_phase_csv(phase_name, arr, path):
    if not arr:
        print(f"skip empty {phase_name}")
        return
    rows = [row_from_sample(s) for s in arr]
    # union of keys preserving order
    keys = []
    seen = set()
    preferred = [
        "capturedAt","phase","attention","focus","engagement","stress","relaxation",
        "interest","excitement","mentalFatigue","distraction",
        "rbp_delta","rbp_theta","rbp_alpha","rbp_beta","rbp_gamma",
        "bp_delta","bp_theta","bp_alpha","bp_beta","bp_gamma",
        "signal","overallQuality","batteryPercent","connection","collecting","timestamp",
    ]
    for k in preferred:
        if any(k in r for r in rows) and k not in seen:
            keys.append(k); seen.add(k)
    for r in rows:
        for k in r.keys():
            if k not in seen:
                keys.append(k); seen.add(k)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    # duration
    t0 = arr[0].get("capturedAt")
    t1 = arr[-1].get("capturedAt")
    try:
        d0 = datetime.fromisoformat(t0.replace("Z","+00:00"))
        d1 = datetime.fromisoformat(t1.replace("Z","+00:00"))
        dur = (d1-d0).total_seconds()
    except Exception:
        dur = None
    print(f"wrote {path} rows={len(rows)} duration_sec={dur}")

for phase in ("reels", "text", "baseline"):
    arr = phases.get(phase) or []
    if not arr:
        continue
    write_phase_csv(phase, arr, os.path.join(out_dir, f"eeg_{phase}_10min.csv"))

# also write combined
all_rows_path = os.path.join(out_dir, "eeg_all_phases.csv")
write_phase_csv("all", samples, all_rows_path)

# minute-by-minute averages for reels and text
def minute_bins(arr):
    if not arr:
        return []
    t0 = datetime.fromisoformat(arr[0]["capturedAt"].replace("Z","+00:00"))
    bins = {}
    for s in arr:
        t = datetime.fromisoformat(s["capturedAt"].replace("Z","+00:00"))
        m = int((t - t0).total_seconds() // 60)
        bins.setdefault(m, []).append(s)
    out = []
    for m in sorted(bins):
        chunk = bins[m]
        rows = [row_from_sample(s) for s in chunk]
        def avg(key):
            vals = [r[key] for r in rows if isinstance(r.get(key), (int, float))]
            return sum(vals)/len(vals) if vals else 0.0
        out.append({
            "minute": m,
            "n": len(chunk),
            "attention": round(avg("attention"), 3),
            "focus": round(avg("focus"), 3),
            "engagement": round(avg("engagement"), 3),
            "stress": round(avg("stress"), 3),
            "relaxation": round(avg("relaxation"), 3),
            "mentalFatigue": round(avg("mentalFatigue"), 3),
            "distraction": round(avg("distraction"), 3),
            "rbp_theta": round(avg("rbp_theta"), 4),
            "rbp_alpha": round(avg("rbp_alpha"), 4),
            "rbp_beta": round(avg("rbp_beta"), 4),
            "rbp_gamma": round(avg("rbp_gamma"), 4),
        })
    return out

for phase in ("reels", "text"):
    arr = phases.get(phase) or []
    mins = minute_bins(arr)
    path = os.path.join(out_dir, f"eeg_{phase}_per_minute.csv")
    if not mins:
        continue
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(mins[0].keys()))
        w.writeheader()
        w.writerows(mins)
    print(f"wrote {path} minutes={len(mins)}")
    for row in mins:
        print(f"  {phase} m{row['minute']:02d}: att={row['attention']} foc={row['focus']} eng={row['engagement']} fat={row['mentalFatigue']} thr={row['rbp_theta']} alp={row['rbp_alpha']} bet={row['rbp_beta']}")
