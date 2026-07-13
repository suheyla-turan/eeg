# Cortex API ayarları — gizli bilgiler .env dosyasından okunur.
# Kurulum: .env.example dosyasını .env olarak kopyala ve değerleri doldur.

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")

CLIENT_ID = os.getenv("EMOTIV_CLIENT_ID", "")
CLIENT_SECRET = os.getenv("EMOTIV_CLIENT_SECRET", "")

HEADSET_ID = os.getenv("EMOTIV_HEADSET_ID", "EPOCX-XXXXXXXX")

URL = os.getenv("CORTEX_URL", "wss://localhost:6868")

LICENSE = os.getenv("EMOTIV_LICENSE", "")
DEBIT = int(os.getenv("EMOTIV_DEBIT", "1"))

BACKEND_URL = os.getenv("BACKEND_URL", "http://0.0.0.0:8000")
BACKEND_PORT = int(os.getenv("BACKEND_PORT", "8000"))
