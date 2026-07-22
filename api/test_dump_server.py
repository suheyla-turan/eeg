"""Test EEG dump sidecar — port 8001.

Ana api_server (8000) yeniden baslatilmadan reel/metin orneklerini yazar.
Flutter bu servise POST eder.
"""

from __future__ import annotations

import uvicorn
from fastapi import Body, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from typing import Any

import test_dump

app = FastAPI(title="EEG Test Dump", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"ok": True, **test_dump.status()}


@app.post("/test/reset")
def test_reset():
    return test_dump.reset()


@app.post("/test/dump")
def test_dump_sample(sample: dict[str, Any] = Body(...)):
    return test_dump.append_sample(sample)


@app.post("/test/finalize")
def test_finalize(payload: dict[str, Any] | None = Body(default=None)):
    return test_dump.finalize(payload)


@app.get("/test/status")
def test_status():
    return test_dump.status()


if __name__ == "__main__":
    print("Test dump sidecar: http://0.0.0.0:8002")
    test_dump.reset()
    uvicorn.run(app, host="0.0.0.0", port=8002, reload=False)
