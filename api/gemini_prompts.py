"""
Gemini EEG analiz prompt'ları.

SYSTEM_PROMPT  → GenerateContentConfig.system_instruction
USER_PROMPT    → build_user_prompt(payload) ile JSON oturum verisinden üretilir
"""

from __future__ import annotations

import statistics
from typing import Any


SYSTEM_PROMPT = """\
Sen EEG verilerini analiz eden uzman bir Nörobilimci ve Veri Analistisin.

## Amacın
Sosyal medya (Reels) ile metin okumanın dikkat, odak ve zihinsel durum \
farklarını herkesin anlayacağı, kısa ve net bir dille açıklamak.

## Uzunluk (ZORUNLU)
- Rapor **kısa** olsun: toplam yaklaşık **250–400 kelime** (en fazla ~450).
- Her madde **1–2 kısa cümle**; uzun paragraf yazma.
- Aynı fikri tekrar etme; yalnızca en çarpıcı tepe/çukur ve sayısal farkları yaz.
- "Sınırlı fark var" gibi yüzeysel ifadeler YASAK; ama lafı uzatma.

## Analiz Kuralları
1. Zaman serisinde **tepe**, **çukur** ve **dalgalanma (SD)** için en fazla \
1–2 somut örnek ver (dakika + skor).
2. **Reels** = dışsal uyaran; **Metin** = içsel efor — bu farkı kısaca bağla.
3. Türkçe yaz; **kalın** ve madde işareti (`*`) kullan.
4. Sayıları düz yaz (örn. 42.1). Klinik tanı koyma; veri yoksa belirt.
5. Kod bloğu / JSON / HTML üretme; yalnızca Markdown.

## Çıktı Formatı (Birebir Bu Başlıklar — Kısa Madde)

## 1. Dikkat (Attention) ve Odak (Focus) Karşılaştırması
* **Reels:** Seviye (ort. Attention/Focus + fark) · Yapı (1 tepe veya SD notu)
* **Metin:** Seviye · Yapı (kararlılık / sapma — 1 örnek)

## 2. Zihinsel Yorgunluk (Mental Fatigue) ve Stres
* **Mental Fatigue:** Reels vs Metin farkı + yenilik etkisi (1 cümle)
* **Stress:** Anlık uyarılma farkı (1 cümle, gerekirse 1 tepe)

## 3. Beyin Dalgası Bandı Analizi (Theta, Alpha, Beta)
* **Beta (β):** Kısa yorum (sayıyla)
* **Theta (θ) / θ/β:** Kısa yorum (sayıyla)

## 📊 Özet Karşılaştırma Tablosu
Tam 5 satır (sadece sayılar):

| Metrik | Reels İzleme | Metin Okuma |
|--------|--------------|-------------|
| Attention | ... | ... |
| Focus | ... | ... |
| Mental Fatigue | ... | ... |
| Stress | ... | ... |
| Theta/Beta (θ/β) | ... | ... |

## 💡 Sonuç ve Yorum
**Dijital Uyarılma Paradoksu** — tam **2 kısa madde** (her biri 1 cümle).

---
*Bu analiz tek oturum verisine dayanmaktadır; tıbbi veya klinik tanı amacı taşımaz.*
"""


USER_PROMPT_TEMPLATE = """\
Aşağıdaki EEG oturum verisini SYSTEM şablonuna göre **kısa** Markdown rapor olarak analiz et.

Kurallar:
- Toplam ~250–400 kelime; madde başına 1–2 cümle.
- Sayısal Reels–Metin farkları + en fazla 1–2 tepe/çukur örneği.
- "Sınırlı fark var" deme; uzun paragraf yazma.

## Oturum meta
- experimentId: {experiment_id}
- participantId: {participant_id}
- analysisVersion: {analysis_version}
- dataInsufficient: {data_insufficient}
- dataInsufficientReason: {data_insufficient_reason}

## Reels aşaması (dışsal görsel-işitsel uyaran)
{reels_block}

## Metin okuma aşaması (içsel zihinsel efor)
{text_block}

## Dakika bazlı zaman serileri
### Reels
{reels_series_block}

### Metin
{text_series_block}

## Ham JSON özeti (referans)
```json
{payload_json}
```

## Ek notlar
{notes}

Şimdi SYSTEM başlıklarıyla **kısa** Markdown raporu üret.
"""


def _fmt_num(value: Any, digits: int = 2) -> str:
    try:
        if value is None:
            return "N/A"
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return "N/A"


def _series_stats(values: list[float]) -> str:
    """Tepe / çukur / ortalama / SD — modelin derin analiz için kullanacağı özet."""
    if not values:
        return ""
    n = len(values)
    mean = statistics.fmean(values)
    peak = max(values)
    trough = min(values)
    peak_min = values.index(peak)  # 0-based dakika indeksi
    trough_min = values.index(trough)
    sd = statistics.pstdev(values) if n > 1 else 0.0
    return (
        f"  özet: ort={_fmt_num(mean, 1)}, "
        f"tepe={_fmt_num(peak, 1)} (dk {peak_min + 1}), "
        f"çukur={_fmt_num(trough, 1)} (dk {trough_min + 1}), "
        f"SD={_fmt_num(sd, 1)}, n={n}"
    )


def _fmt_series(label: str, values: list[float] | None) -> str:
    if not values:
        return f"- {label}: (veri yok)"
    rounded = ", ".join(_fmt_num(v, 1) for v in values)
    stats = _series_stats(values)
    return f"- {label} (n={len(values)}): [{rounded}]\n{stats}"


def _phase_block(phase: dict[str, Any], label: str) -> str:
    if not phase:
        return f"(Veri yok — {label})"

    lines = [
        f"- Süre (sn): {_fmt_num(phase.get('durationSeconds'), 0)}",
        f"- Örnek sayısı: {phase.get('sampleCount', 'N/A')}",
        f"- dataInsufficient: {phase.get('dataInsufficient', False)}",
        f"- **Attention**: {_fmt_num(phase.get('attention'))}",
        f"- **Focus**: {_fmt_num(phase.get('focus'))}",
        f"- **Stress**: {_fmt_num(phase.get('stress'))}",
        f"- **Engagement**: {_fmt_num(phase.get('engagement'))}",
        f"- **Mental Fatigue**: {_fmt_num(phase.get('mentalFatigue'))}",
        f"- Distraction: {_fmt_num(phase.get('distraction'))}",
        f"- Relaxation: {_fmt_num(phase.get('relaxation'))}",
        f"- Interest: {_fmt_num(phase.get('interest'))}",
        f"- Excitement: {_fmt_num(phase.get('excitement'))}",
        f"- Alpha %: {_fmt_num(phase.get('alpha'))}",
        f"- Beta %: {_fmt_num(phase.get('beta'))}",
        f"- Theta %: {_fmt_num(phase.get('theta'))}",
        f"- Gamma %: {_fmt_num(phase.get('gamma'))}",
        f"- **Theta/Beta (θ/β)**: {_fmt_num(phase.get('thetaBeta'), 3)}",
        f"- Alpha/Beta: {_fmt_num(phase.get('alphaBeta'), 3)}",
        f"- Beta/Alpha: {_fmt_num(phase.get('betaAlpha'), 3)}",
    ]
    return "\n".join(lines)


def _series_block(series: dict[str, list[float]] | None) -> str:
    if not series:
        return "(Dakika serisi yok)"
    parts = [
        _fmt_series("Attention", series.get("attention")),
        _fmt_series("Focus", series.get("focus")),
        _fmt_series("Stress", series.get("stress")),
        _fmt_series("Engagement", series.get("engagement")),
        _fmt_series("Mental Fatigue", series.get("mentalFatigue")),
        _fmt_series("Theta/Beta", series.get("thetaBeta")),
    ]
    return "\n".join(parts)


def _compact_payload_json(payload: dict[str, Any]) -> str:
    """Prompt içine gömülen kompakt JSON (okunabilir, aşırı uzun değil)."""
    import json

    compact = {
        "experimentId": payload.get("experimentId"),
        "participantId": payload.get("participantId"),
        "analysisVersion": payload.get("analysisVersion"),
        "dataInsufficient": payload.get("dataInsufficient"),
        "reels": payload.get("reels") or {},
        "text": payload.get("text") or {},
        "reelsMinuteSeries": payload.get("reelsMinuteSeries"),
        "textMinuteSeries": payload.get("textMinuteSeries"),
    }
    return json.dumps(compact, ensure_ascii=False, indent=2)


def build_user_prompt(payload: dict[str, Any]) -> str:
    """
    Flutter / API'den gelen oturum JSON'unu Gemini kullanıcı mesajına çevirir.

    Beklenen payload alanları (SessionAnalysisRequest ile uyumlu):
      experimentId, participantId, analysisVersion,
      dataInsufficient, dataInsufficientReason, notes,
      reels: PhaseMetrics dict,
      text: PhaseMetrics dict,
      reelsMinuteSeries / textMinuteSeries: {
        attention, focus, stress, engagement, mentalFatigue, thetaBeta: list[float]
      }

    Kullanım (Gemini API çağrısı):
      from gemini_prompts import SYSTEM_PROMPT, build_user_prompt
      user_prompt = build_user_prompt(payload)
      client.models.generate_content(
          model=...,
          contents=user_prompt,
          config=GenerateContentConfig(system_instruction=SYSTEM_PROMPT, ...),
      )
    """
    return USER_PROMPT_TEMPLATE.format(
        experiment_id=payload.get("experimentId", "N/A"),
        participant_id=payload.get("participantId", "N/A"),
        analysis_version=payload.get("analysisVersion", "N/A"),
        data_insufficient=payload.get("dataInsufficient", False),
        data_insufficient_reason=payload.get("dataInsufficientReason") or "—",
        reels_block=_phase_block(payload.get("reels") or {}, "Reels"),
        text_block=_phase_block(payload.get("text") or {}, "Metin"),
        reels_series_block=_series_block(payload.get("reelsMinuteSeries")),
        text_series_block=_series_block(payload.get("textMinuteSeries")),
        payload_json=_compact_payload_json(payload),
        notes=payload.get("notes") or "Yok",
    )


def build_gemini_contents(payload: dict[str, Any]) -> dict[str, str]:
    """
    Gemini çağrısı için system + user çiftini döndürür.

    Returns:
        {"system_instruction": SYSTEM_PROMPT, "user_prompt": "..."}
    """
    return {
        "system_instruction": SYSTEM_PROMPT,
        "user_prompt": build_user_prompt(payload),
    }
