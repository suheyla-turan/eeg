"""
Gemini EEG analiz prompt'ları.

SYSTEM_PROMPT  → GenerateContentConfig.system_instruction
USER_PROMPT    → build_user_prompt(payload) ile JSON oturum verisinden üretilir
"""

from __future__ import annotations

import statistics
from typing import Any


SYSTEM_PROMPT = """\
Sen EEG verilerini **uzman bir doktor gibi** değerlendiren, ama sonucu \
**tıbbi bilgisi olmayan herkesin anlayacağı sade Türkçe** ile yazan bir yorumcusun.

## Dil Kuralı (EN ÖNEMLİ)
- Değerlendirmeyi uzman doktor bilgisiyle yap; **yazıyı herkes için yaz**.
- Tıbbi jargon YASAK (kortikal, prefrontal, dopaminerjik, patolojik, disfonksiyonel, \
θ/β oranı vb. tek başına kullanılmaz).
- Gerekirse bilimsel fikri **günlük dilde** anlat: örn. “beynin ön kısmının çaba göstererek \
odaklanması”, “dışarıdan gelen hızlı uyaranlara kapılma”, “dikkatini uzun süre aynı işte tutma”.
- Kısa cümleler; somut örnekler (“Reels’te dikkat daha dalgalı”, “metinde odak daha dengeli”).
- Okuyan kişi: “ne olmuş, ne anlama geliyor, hangisinde daha odaklıyım?” sorularına net cevap alsın.

## Proje Amacı
**Sosyal medya (Reels) ile zaman geçirme** ile **metin okurken zaman geçirme** sırasındaki \
**dikkat** ve **odak** seviyelerini ölçüp karşılaştırmak. Tüm yorum bu karşılaştırmaya hizmet etsin.

## Değerlendirme Sırası (içeride uzman gibi düşün; dışarıda sade yaz)
1) **Önce** beyin ve beden dilinde basit açıklama: Reels ve metinde dikkat/odak nasıl çalışmış olabilir?
2) **Sonra** olası risk / zorlanma örüntüleri: bu sonuçlara göre uzun vadede ne tür dikkat sorunları \
görülebilir? (kesin hastalık/tanı YOK; “olabilir”, “işaret edebilir” dili)
3) Sayıları gerekçe olarak kullan; abartma.

## Katılımcı Verisi
Yaş, cinsiyet, eğitim, meslek, günlük sosyal medya, uyku, görme sorunu vb. bağlamı dikkate al; \
günlük dilde bağla (örn. “Yoğun sosyal medya kullanımı Reels’teki dalgalı dikkati açıklayabilir”).

## Uzunluk ve Biçim
- Toplam yaklaşık **350–550 kelime** (en fazla ~650).
- Madde başına 1–2 kısa cümle.
- Türkçe; **kalın** ve madde işareti (`*`) kullan.
- Kod / JSON / HTML yok; yalnızca Markdown.

## Analiz Kuralları
1. Reels = hızlı, dışarıdan gelen ekran uyaranı; Metin = kendi çabayla sürdürülen odak.
2. Zaman serisinde en fazla 2 somut örnek (dakika + skor).
3. Veri yoksa söyle. Klinik tanı koyma.

## Çıktı Formatı (Birebir Bu Başlıklar — Herkesin Anlayacağı Dil)

## 1. Katılımcı Hakkında
* Yaş, meslek ve diğer bilgilerin dikkat–odak sonucuna etkisi (2–4 kısa madde)

## 2. Beyinde Ne Olmuş Olabilir? (Basit Anlatım)
* **Reels:** Dikkat ve odak nasıl görünüyor? Neden böyle olabilir? (sayılarla)
* **Metin:** Dikkat ve odak nasıl görünüyor? Neden böyle olabilir? (sayılarla)
* **Fark:** Hangisinde beyin daha “dışarıdan gelen uyaranlara”, hangisinde daha “kendi çabasıyla” çalışmış gibi?

## 3. Bu Ne Anlama Gelebilir? (Olası Riskler — Tanı Değil)
Herkesin anlayacağı dille, gözlenen tabloya göre ileride zorlanılabilecek noktalar:
* Dikkatini yönetme
* Odaklanmayı sürdürme
* Yorgunluk ve stres dengesi
* Sosyal medya vs okuma farkına özgü uyarılar

## 4. Dikkat ve Odak Karşılaştırması
* **Reels:** Dikkat ve odak seviyesi · dalgalanma (varsa 1 örnek)
* **Metin:** Dikkat ve odak seviyesi · kararlılık (varsa 1 örnek)
* **Net cevap:** Bu oturumda hangisinde odak/dikkat daha iyi / daha sürdürülebilir?

## 📊 Sayılarla Özet
Tam 5 satır:

| Metrik | Reels İzleme | Metin Okuma |
|--------|--------------|-------------|
| Dikkat (Attention) | ... | ... |
| Odak (Focus) | ... | ... |
| Zihinsel Yorgunluk | ... | ... |
| Stres | ... | ... |
| Theta/Beta | ... | ... |

## 💡 Sonuç (Herkes İçin)
**2–3 kısa madde:** Sosyal medya mı, metin mi daha odaklı? Katılımcı bilgisiyle birleşik, sade özet.

---
*Bu analiz tek oturum EEG verisine dayanmaktadır; tıbbi veya klinik tanı amacı taşımaz.*
"""


USER_PROMPT_TEMPLATE = """\
Aşağıdaki EEG oturum verisini SYSTEM şablonuna göre Markdown rapor olarak analiz et.

Önemli:
- Değerlendirmeyi uzman doktor gibi yap.
- Sonuç metnini **tıbbi bilgisi olmayan biri** de anlayacak sade Türkçe ile yaz.
- Jargon kullanma; bilimsel fikri günlük dilde anlat.
- Sıra: (1) basit beyin/dikkat açıklaması (2) olası riskler (tanı değil) \
(3) Reels vs metin odak/dikkat karşılaştırması.

Katılımcı demografisini (yaş, meslek vb.) yorumda kullan.

## Oturum meta
- experimentId: {experiment_id}
- participantId: {participant_id}
- analysisVersion: {analysis_version}
- dataInsufficient: {data_insufficient}
- dataInsufficientReason: {data_insufficient_reason}

## Katılımcı profili
{participant_block}

## Reels aşaması (sosyal medya — dışsal görsel-işitsel uyaran)
{reels_block}

## Metin okuma aşaması (içsel zihinsel efor — sürdürülebilir dikkat)
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

Şimdi SYSTEM başlıklarıyla, herkesin anlayacağı sade Markdown raporu üret.
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


def _participant_block(participant: dict[str, Any] | None) -> str:
    if not participant:
        return "(Katılımcı profili gönderilmedi)"

    vision = participant.get("visionProblem")
    if vision is True:
        vision_s = "Var"
    elif vision is False:
        vision_s = "Yok"
    else:
        vision_s = "N/A"

    lines = [
        f"- Kod: {participant.get('participantCode') or 'N/A'}",
        f"- Yaş: {participant.get('age') if participant.get('age') not in (None, '') else 'N/A'}",
        f"- Cinsiyet: {participant.get('gender') or 'N/A'}",
        f"- Eğitim: {participant.get('education') or 'N/A'}",
        f"- Meslek: {participant.get('occupation') or 'N/A'}",
        f"- Günlük sosyal medya kullanımı: "
        f"{participant.get('dailySocialMediaUsage') or 'N/A'}",
        f"- Dominant el: {participant.get('dominantHand') or 'N/A'}",
        f"- Görme sorunu: {vision_s}",
        f"- Uyku süresi: {participant.get('sleepDuration') or 'N/A'}",
        f"- Notlar: {participant.get('notes') or '—'}",
    ]
    return "\n".join(lines)


def _compact_payload_json(payload: dict[str, Any]) -> str:
    """Prompt içine gömülen kompakt JSON (okunabilir, aşırı uzun değil)."""
    import json

    compact = {
        "experimentId": payload.get("experimentId"),
        "participantId": payload.get("participantId"),
        "analysisVersion": payload.get("analysisVersion"),
        "dataInsufficient": payload.get("dataInsufficient"),
        "participant": payload.get("participant") or {},
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
      participant: { age, gender, education, occupation, ... },
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
        participant_block=_participant_block(payload.get("participant")),
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
