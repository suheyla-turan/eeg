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

İlk kurulum:

```bash
cd api
python -m venv .venv
# Windows:
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# .env içine Emotiv CLIENT_ID / CLIENT_SECRET yaz
```

### Otomatik başlatma (önerilen)

Elle `python api_server.py` çalıştırmana gerek kalmasın diye Windows oturumunda API’yi otomatik ayağa kaldır:

```powershell
cd api
powershell -ExecutionPolicy Bypass -File .\install_autostart.ps1
```

Bu komut:
- Oturum açılışında API’yi başlatır
- Her 2 dakikada bir kontrol eder; kapandıysa yeniden açar
- USB telefon bağlıysa `adb reverse tcp:8000` tünelini yeniler
- Zaten çalışıyorsa dokunmaz

Manuel tek seferlik başlatma: `api\start_api.bat` (çift tık).

Kaldırma: `.\install_autostart.ps1 -Uninstall`

Başarılı başlangıçta `http://127.0.0.1:8000/health` yanıt verir; mDNS adı `eegserver.local`.

Gizli bilgiler yalnızca `api/.env` içinde (Git’e gitmez). Repoda `api/.env.example` örneği vardır.

## 2) Flutter uygulama

Tek komut (API + USB tüneli + flutter run):

```powershell
cd api
powershell -ExecutionPolicy Bypass -File .\run_device.ps1
```

Veya Cursor/VS Code’da **EEG Mobil (API + adb reverse)** launch yapılandırması
(önce `ensure_running` çalışır).

Elle:

```bash
cd EEG_Mobil
flutter pub get
flutter run
```

Emülatör veya USB tüneli (gerekirse):

```bash
cd api
powershell -ExecutionPolicy Bypass -File .\link_phone.ps1
```

Uygulama son başarılı API host’unu hatırlar. mDNS fiziksel telefonda
(özellikle Xiaomi) sık başarısız olur; gerekirse Ayarlar’da
**Host override** = PC Wi‑Fi IP (örn. `192.168.1.113`).

## Akış

1. Emotiv Launcher açık + headset bağlı olsun
2. Bir kez `install_autostart.ps1` çalıştır (API + adb reverse otomatik)
3. Telefonu USB veya aynı Wi‑Fi’ye bağla
4. Flutter’da **Demo modu kapalı** → canlı EEG akar
