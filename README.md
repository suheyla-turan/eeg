# EEG — Mobil + Python API

Emotiv Cortex üzerinden EEG verisi toplayan Python API ve Flutter mobil uygulaması.

```
eeg/
├── api/          # Python FastAPI (Cortex → HTTP)
└── EEG_Mobil/    # Flutter mobil uygulama
```

## 1) Python API

```bash
cd api
python -m venv .venv
# Windows:
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# .env içine Emotiv CLIENT_ID / CLIENT_SECRET yaz
python api_server.py
```

API: `http://127.0.0.1:8000`

Gizli bilgiler yalnızca `api/.env` içinde (Git’e gitmez). Repoda `api/.env.example` örneği vardır.

## 2) Flutter uygulama

```bash
cd EEG_Mobil
flutter pub get
flutter run
```

Android emülatör için (API’ye erişim):

```bash
adb reverse tcp:8000 tcp:8000
```

## Akış

1. `python api_server.py` çalıştır
2. Emülatörde `adb reverse` yap
3. Uygulamada **Başlat** → Cortex’e bağlanır, canlı veri akar
