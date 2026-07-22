import json, csv, os, math
from datetime import datetime, timezone

path = r"c:\Users\msi\Desktop\eeg\_export\eeg_raw.json"
out_dir = r"c:\Users\msi\Desktop\eeg\_export"
desktop = r"c:\Users\msi\Desktop"

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

samples = data.get("samples") or []
CHANNELS = ["AF3","F7","F3","FC5","T7","P7","O1","O2","P8","T8","FC6","F4","F8","AF4"]

def parse_t(s):
    raw = s.get("capturedAt")
    if not raw: return None
    return datetime.fromisoformat(raw.replace("Z", "+00:00"))

def get_bands(s):
    rbp = s.get("relativeBandPower") if isinstance(s.get("relativeBandPower"), dict) else {}
    bp = s.get("bandPower") if isinstance(s.get("bandPower"), dict) else {}
    def g(d, k):
        try: return float(d.get(k) or 0)
        except: return 0.0
    # prefer relative; if relative missing/zero use absolute normalized
    rel = {k: g(rbp, k) for k in ("delta","theta","alpha","beta","gamma")}
    absb = {k: g(bp, k) for k in ("delta","theta","alpha","beta","gamma")}
    if sum(rel.values()) <= 1e-12:
        tot = sum(absb.values())
        if tot > 1e-12:
            rel = {k: absb[k]/tot for k in absb}
    return rel, absb

def ratio_to_score(ratio, midpoint, scale=0.85):
    if ratio <= 0 or not math.isfinite(ratio):
        return 0.0
    x = math.log(ratio)
    m = math.log(midpoint)
    z = (x - m) / scale
    return max(1.0, min(99.0, 100.0 / (1.0 + math.exp(-z))))

def scores_from_rel(b):
    eps = 1e-6
    theta, alpha, beta, gamma = b["theta"], b["alpha"], b["beta"], b["gamma"]
    focus_r = beta / (theta + alpha + eps)
    engagement_r = (beta + gamma) / (theta + eps)
    attn_tbr = beta / (theta + eps)
    fatigue_r = theta / (alpha + eps)
    relax_r = alpha / (alpha + beta + eps)
    stress_r = beta / (alpha + eps)
    distract_r = theta / (beta + gamma + eps)
    focus = ratio_to_score(focus_r, 0.55)
    engagement = ratio_to_score(engagement_r, 1.2)
    mentalFatigue = ratio_to_score(fatigue_r, 1.0)
    relaxation = ratio_to_score(relax_r, 0.55)
    stress = ratio_to_score(stress_r, 1.0)
    distraction = ratio_to_score(distract_r, 0.8)
    attnFromTbr = ratio_to_score(attn_tbr, 1.0)
    attention = max(1.0, min(99.0, 0.55 * attnFromTbr + 0.45 * engagement))
    excitement = ratio_to_score(max(1e-6, min(10.0, gamma + engagement_r * 0.15)), 0.25)
    interest = max(1.0, min(99.0, 0.7 * engagement + 0.3 * excitement))
    return {
        "attention": attention,
        "focus": focus,
        "engagement": engagement,
        "mentalFatigue": mentalFatigue,
        "relaxation": relaxation,
        "stress": stress,
        "distraction": distraction,
        "interest": interest,
        "excitement": excitement,
        "thetaBeta": theta / (beta + eps),
        "alphaBeta": alpha / (beta + eps),
        "betaAlpha": beta / (alpha + eps),
    }

def row_from_sample(s):
    eeg = s.get("eeg") if isinstance(s.get("eeg"), dict) else {}
    rel, absb = get_bands(s)
    sc = scores_from_rel(rel) if sum(rel.values()) > 1e-12 else {k: 0.0 for k in (
        "attention","focus","engagement","mentalFatigue","relaxation","stress",
        "distraction","interest","excitement","thetaBeta","alphaBeta","betaAlpha")}
    row = {
        "capturedAt": s.get("capturedAt") or "",
        "phase": s.get("phase") or "",
        "signal": float(s.get("signal") or 0),
        "overallQuality": float(s.get("overallQuality") or 0),
        "batteryPercent": float(s.get("batteryPercent") or 0),
        "connection": s.get("connection") or "",
        "collecting": bool(s.get("collecting")),
        "attention": round(sc["attention"], 4),
        "focus": round(sc["focus"], 4),
        "engagement": round(sc["engagement"], 4),
        "mentalFatigue": round(sc["mentalFatigue"], 4),
        "relaxation": round(sc["relaxation"], 4),
        "stress": round(sc["stress"], 4),
        "distraction": round(sc["distraction"], 4),
        "interest": round(sc["interest"], 4),
        "excitement": round(sc["excitement"], 4),
        "thetaBeta": round(sc["thetaBeta"], 6),
        "alphaBeta": round(sc["alphaBeta"], 6),
        "betaAlpha": round(sc["betaAlpha"], 6),
        "rbp_delta": round(rel["delta"], 6),
        "rbp_theta": round(rel["theta"], 6),
        "rbp_alpha": round(rel["alpha"], 6),
        "rbp_beta": round(rel["beta"], 6),
        "rbp_gamma": round(rel["gamma"], 6),
        "bp_delta": round(absb["delta"], 8),
        "bp_theta": round(absb["theta"], 8),
        "bp_alpha": round(absb["alpha"], 8),
        "bp_beta": round(absb["beta"], 8),
        "bp_gamma": round(absb["gamma"], 8),
    }
    for ch in CHANNELS:
        try:
            row[f"ch_{ch}"] = float(eeg.get(ch) or 0)
        except Exception:
            row[f"ch_{ch}"] = 0.0
    return row

def write_csv(path, rows):
    if not rows: return
    keys = list(rows[0].keys())
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {path} n={len(rows)}")

phases = {}
for s in samples:
    phases.setdefault(s.get("phase") or "unknown", []).append(s)

for phase in ("reels", "text"):
    arr = phases.get(phase) or []
    rows = [row_from_sample(s) for s in arr]
    write_csv(os.path.join(out_dir, f"eeg_{phase}_samples.csv"), rows)
    write_csv(os.path.join(desktop, f"EEG_{phase}_10dk.csv"), rows)

    # per minute
    if not arr: continue
    t0 = parse_t(arr[0])
    bins = {}
    for s in arr:
        t = parse_t(s)
        m = int((t - t0).total_seconds() // 60) if t and t0 else 0
        bins.setdefault(m, []).append(s)
    mins = []
    for m in sorted(bins):
        rs = [row_from_sample(s) for s in bins[m]]
        def avg(k):
            vals = [r[k] for r in rs if isinstance(r.get(k), (int, float))]
            return sum(vals)/len(vals) if vals else 0.0
        mins.append({
            "minute": m,
            "n_samples": len(rs),
            "attention": round(avg("attention"), 3),
            "focus": round(avg("focus"), 3),
            "engagement": round(avg("engagement"), 3),
            "mentalFatigue": round(avg("mentalFatigue"), 3),
            "stress": round(avg("stress"), 3),
            "relaxation": round(avg("relaxation"), 3),
            "distraction": round(avg("distraction"), 3),
            "interest": round(avg("interest"), 3),
            "excitement": round(avg("excitement"), 3),
            "thetaBeta": round(avg("thetaBeta"), 4),
            "alphaBeta": round(avg("alphaBeta"), 4),
            "rbp_theta_pct": round(avg("rbp_theta")*100, 3),
            "rbp_alpha_pct": round(avg("rbp_alpha")*100, 3),
            "rbp_beta_pct": round(avg("rbp_beta")*100, 3),
            "rbp_gamma_pct": round(avg("rbp_gamma")*100, 3),
        })
    write_csv(os.path.join(out_dir, f"eeg_{phase}_per_minute.csv"), mins)
    write_csv(os.path.join(desktop, f"EEG_{phase}_dakika.csv"), mins)
    print(f"=== {phase} dakika ozeti ===")
    for r in mins:
        print(f"  dk{r['minute']:02d} n={r['n_samples']} att={r['attention']} foc={r['focus']} eng={r['engagement']} fat={r['mentalFatigue']} str={r['stress']} thr%={r['rbp_theta_pct']} alp%={r['rbp_alpha_pct']} bet%={r['rbp_beta_pct']}")

# durations
for phase in ("reels","text"):
    arr = phases.get(phase) or []
    if len(arr) >= 2:
        d = (parse_t(arr[-1]) - parse_t(arr[0])).total_seconds()
        print(f"{phase}: samples={len(arr)} duration_sec={d:.1f} (~{d/60:.2f} dk)")
