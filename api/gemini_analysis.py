"""
Gemini EEG oturum analizi servisi.

Flutter / dış istemciden gelen Reels + Metin metriklerini alır,
prompt şablonunu doldurur ve Google Gemini API'ye istek atar.
"""

from __future__ import annotations

import statistics
from typing import Any

from pydantic import BaseModel, Field

from config import GEMINI_API_KEY, GEMINI_MODEL
from gemini_prompts import build_gemini_contents


# ---------------------------------------------------------------------------
# Request / response modelleri
# ---------------------------------------------------------------------------


class PhaseMetricsIn(BaseModel):
    """Tek aşama (reels / text) özet skorları — Flutter PhaseMetrics ile uyumlu."""

    phase: str = ""
    attention: float = 0
    focus: float = 0
    stress: float = 0
    engagement: float = 0
    relaxation: float = 0
    interest: float = 0
    excitement: float = 0
    mentalFatigue: float = 0
    distraction: float = 0
    alpha: float = 0
    beta: float = 0
    theta: float = 0
    delta: float = 0
    gamma: float = 0
    thetaBeta: float = 0
    alphaBeta: float = 0
    betaAlpha: float = 0
    sampleCount: int = 0
    durationSeconds: int = 0
    dataInsufficient: bool = False


class MinuteSeriesIn(BaseModel):
    """Dakika bazlı zaman serileri (indeks = dakika)."""

    attention: list[float] = Field(default_factory=list)
    focus: list[float] = Field(default_factory=list)
    stress: list[float] = Field(default_factory=list)
    engagement: list[float] = Field(default_factory=list)
    mentalFatigue: list[float] = Field(default_factory=list)
    thetaBeta: list[float] = Field(default_factory=list)


class SessionAnalysisRequest(BaseModel):
    """Gemini analiz isteği gövdesi."""

    experimentId: str = ""
    participantId: str = ""
    analysisVersion: int = 3
    dataInsufficient: bool = False
    dataInsufficientReason: str = ""
    notes: str = ""

    reels: PhaseMetricsIn = Field(default_factory=PhaseMetricsIn)
    text: PhaseMetricsIn = Field(default_factory=PhaseMetricsIn)

    reelsMinuteSeries: MinuteSeriesIn | None = None
    textMinuteSeries: MinuteSeriesIn | None = None

    # Flutter ExperimentResult epoch serileri (~2 sn) — dakika yoksa buradan türetilir
    attentionSeries: list[float] = Field(default_factory=list)
    focusSeries: list[float] = Field(default_factory=list)
    stressSeries: list[float] = Field(default_factory=list)
    engagementSeries: list[float] = Field(default_factory=list)

    model: str | None = None  # örn. gemini-3.6-flash; boşsa config varsayılanı
    temperature: float = 0.4
    # Düşünme modellerinde thinking tokenleri de buradan düşer; kısa rapor için bile yüksek tut.
    maxOutputTokens: int = 4096


class SessionAnalysisResponse(BaseModel):
    ok: bool
    model: str
    markdown: str
    promptChars: int = 0
    error: str | None = None


# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------


def _bucket_means(values: list[float], bucket_count: int) -> list[float]:
    """Epoch serisini yaklaşık N dakikalık ortalamalara böler."""
    if not values or bucket_count <= 0:
        return []
    n = len(values)
    if bucket_count >= n:
        return [float(v) for v in values]

    out: list[float] = []
    for i in range(bucket_count):
        start = int(i * n / bucket_count)
        end = int((i + 1) * n / bucket_count)
        chunk = values[start:end]
        if chunk:
            out.append(float(statistics.fmean(chunk)))
    return out


def _infer_minute_series(
    req: SessionAnalysisRequest,
) -> tuple[dict[str, list[float]] | None, dict[str, list[float]] | None]:
    """
    İstemci dakika serisi göndermediyse, genel epoch serisini
    reels/text sürelerine göre ikiye bölüp dakikalık ortalamalara çevirir.
    """
    reels_ms = req.reelsMinuteSeries.model_dump() if req.reelsMinuteSeries else None
    text_ms = req.textMinuteSeries.model_dump() if req.textMinuteSeries else None

    has_any = any(
        (reels_ms or {}).get(k) or (text_ms or {}).get(k)
        for k in ("attention", "focus", "stress", "engagement", "mentalFatigue", "thetaBeta")
    )
    if has_any:
        return reels_ms, text_ms

    # Epoch serisi yoksa türetemeyiz
    if not (
        req.attentionSeries
        or req.focusSeries
        or req.stressSeries
        or req.engagementSeries
    ):
        return None, None

    reels_sec = max(int(req.reels.durationSeconds or 0), 0)
    text_sec = max(int(req.text.durationSeconds or 0), 0)
    total_sec = reels_sec + text_sec

    def split_and_bucket(series: list[float]) -> tuple[list[float], list[float]]:
        if not series:
            return [], []
        if total_sec <= 0:
            mid = len(series) // 2
            left, right = series[:mid], series[mid:]
            reels_min = max(reels_sec // 60, 1) if reels_sec else max(len(left) // 30, 1)
            text_min = max(text_sec // 60, 1) if text_sec else max(len(right) // 30, 1)
            return _bucket_means(left, reels_min), _bucket_means(right, text_min)

        split_idx = int(len(series) * (reels_sec / total_sec)) if total_sec else len(series) // 2
        left, right = series[:split_idx], series[split_idx:]
        reels_min = max(reels_sec // 60, 1)
        text_min = max(text_sec // 60, 1)
        return _bucket_means(left, reels_min), _bucket_means(right, text_min)

    att_r, att_t = split_and_bucket(req.attentionSeries)
    foc_r, foc_t = split_and_bucket(req.focusSeries)
    str_r, str_t = split_and_bucket(req.stressSeries)
    eng_r, eng_t = split_and_bucket(req.engagementSeries)

    return (
        {
            "attention": att_r,
            "focus": foc_r,
            "stress": str_r,
            "engagement": eng_r,
            "mentalFatigue": [],
            "thetaBeta": [],
        },
        {
            "attention": att_t,
            "focus": foc_t,
            "stress": str_t,
            "engagement": eng_t,
            "mentalFatigue": [],
            "thetaBeta": [],
        },
    )


def _request_to_prompt_payload(req: SessionAnalysisRequest) -> dict[str, Any]:
    reels_ms, text_ms = _infer_minute_series(req)
    return {
        "experimentId": req.experimentId,
        "participantId": req.participantId,
        "analysisVersion": req.analysisVersion,
        "dataInsufficient": req.dataInsufficient,
        "dataInsufficientReason": req.dataInsufficientReason,
        "notes": req.notes,
        "reels": req.reels.model_dump(),
        "text": req.text.model_dump(),
        "reelsMinuteSeries": reels_ms,
        "textMinuteSeries": text_ms,
    }


# ---------------------------------------------------------------------------
# Gemini çağrısı
# ---------------------------------------------------------------------------


class GeminiConfigError(RuntimeError):
    """API anahtarı veya model yapılandırması eksik."""


def analyze_session(req: SessionAnalysisRequest) -> SessionAnalysisResponse:
    """
    EEG oturum verisini Gemini'ye gönderir; Markdown analiz döner.

    Kullanım:
        from gemini_analysis import SessionAnalysisRequest, analyze_session
        result = analyze_session(SessionAnalysisRequest(...))
        print(result.markdown)
    """
    api_key = (GEMINI_API_KEY or "").strip()
    if not api_key:
        return SessionAnalysisResponse(
            ok=False,
            model=req.model or GEMINI_MODEL,
            markdown="",
            error="GEMINI_API_KEY tanımlı değil. api/.env dosyasına ekleyin.",
        )

    model_name = (req.model or GEMINI_MODEL or "gemini-3.6-flash").strip()
    prompt_payload = _request_to_prompt_payload(req)
    # SYSTEM_PROMPT → system_instruction; JSON oturum verisi → user prompt
    prompts = build_gemini_contents(prompt_payload)
    user_prompt = prompts["user_prompt"]

    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return SessionAnalysisResponse(
            ok=False,
            model=model_name,
            markdown="",
            promptChars=len(user_prompt),
            error="google-genai paketi yüklü değil. pip install google-genai",
        )

    try:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model=model_name,
            contents=user_prompt,
            config=types.GenerateContentConfig(
                system_instruction=prompts["system_instruction"],
                temperature=req.temperature,
                max_output_tokens=req.maxOutputTokens,
            ),
        )
        text = (response.text or "").strip()
        if not text:
            return SessionAnalysisResponse(
                ok=False,
                model=model_name,
                markdown="",
                promptChars=len(user_prompt),
                error="Gemini boş yanıt döndü.",
            )

        # Güvenlik: disclaimer yoksa ekle
        disclaimer = (
            "*Bu analiz tek oturum verisine dayanmaktadır; "
            "tıbbi veya klinik tanı amacı taşımaz.*"
        )
        if "tıbbi veya klinik tanı amacı taşımaz" not in text:
            text = f"{text.rstrip()}\n\n---\n{disclaimer}"

        return SessionAnalysisResponse(
            ok=True,
            model=model_name,
            markdown=text,
            promptChars=len(user_prompt),
        )
    except Exception as exc:  # noqa: BLE001 — API hatalarını istemciye ilet
        return SessionAnalysisResponse(
            ok=False,
            model=model_name,
            markdown="",
            promptChars=len(user_prompt),
            error=f"Gemini API hatası: {exc}",
        )


async def analyze_session_async(req: SessionAnalysisRequest) -> SessionAnalysisResponse:
    """Async sarmalayıcı — FastAPI endpoint'leri için."""
    import asyncio

    return await asyncio.to_thread(analyze_session, req)
