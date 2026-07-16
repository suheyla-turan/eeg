# EEG — Mobil + Python API

Emotiv Cortex üzerinden EEG verisi toplayan Python API ve Flutter mobil uygulaması.

```
eeg/
├── api/          # Python FastAPI (Cortex → HTTP + mDNS)
└── EEG_Mobil/    # Flutter mobil uygulama
```

## Bağlantı (mDNS / Bonjour)

API bilgisayarda `eegserver.local` olarak yayınlanır. Flutter IP yazmadan keşfeder;
PC IP’si değişse bile aynı isimle çalışır.

- Adres: `http://eegserver.local:8000`
- Servis: `eegserver._eeg-api._tcp.local.`
- Telefon ve PC **aynı Wi‑Fi** ağında olmalı

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

Başarılı başlangıçta konsolda şuna benzer satır görünür:

```
mDNS yayında: http://eegserver.local:8000  (192.168.x.x)
```

Gizli bilgiler yalnızca `api/.env` içinde (Git’e gitmez). Repoda `api/.env.example` örneği vardır.

## 2) Flutter uygulama

```bash
cd EEG_Mobil
flutter pub get
flutter run
```

Emülatör yedeği (mDNS emülatörde bazen çalışmaz):

```bash
adb reverse tcp:8000 tcp:8000
```

## Akış

1. `python api_server.py` çalıştır (mDNS yayını otomatik başlar)
2. Telefonu aynı Wi‑Fi’ye bağla
3. Flutter’ı aç → `eegserver.local` keşfedilir
4. Uygulamada **Başlat** → Cortex’e bağlanır, canlı veri akar
