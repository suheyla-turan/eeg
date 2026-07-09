# EEG AI Project

Emotiv EPOC X EEG cihazından gelen verileri işleyen ve Android mobil uygulamada gösteren proje.

## Proje Yapısı

```
EEG_AI_Project/
├── backend/          # FastAPI sunucu (mobil + cortex köprüsü)
├── mobile/           # Flutter Android uygulaması
├── cortex_client.py  # Emotiv Cortex WebSocket istemcisi
├── main.py           # EEG veri toplama giriş noktası
└── config.py         # Cortex ve backend ayarları
```

## Kurulum

### 1. Python bağımlılıkları

```bash
pip install -r requirements.txt
pip install -r backend/requirements.txt
```

### 2. Backend sunucuyu başlat

```bash
cd backend
python main.py
```

Sunucu `http://0.0.0.0:8000` adresinde çalışır.

### 3. EEG veri toplamayı başlat

Emotiv Cortex uygulaması açık ve headset bağlı olmalı.

```bash
python main.py
```

### 4. Flutter mobil uygulama

```bash
cd mobile
flutter pub get
flutter run
```

## Mobil Bağlantı Ayarları

| Ortam | Sunucu adresi |
|---|---|
| Android emülatör | `10.0.2.2` |
| Gerçek telefon | Bilgisayarın yerel IP adresi (ör. `192.168.1.25`) |

Uygulama içindeki **Ayarlar** ekranından sunucu IP'si değiştirilebilir.

## Duygu Yorumlama (AI - Sonraki Aşama)

Mobil uygulama şu duygu alanlarını gösterir:

- Mutluluk
- Öfke
- Uyku hali
- Stres
- Odak
- Üzüntü
- Sakinlik

AI modeli eklendiğinde backend `/api/emotions` endpoint'i üzerinden skorlar mobil uygulamaya iletilecek. Şu an bu alanlar `AI bekleniyor` durumunda.

## Çalışma Akışı

1. Cortex Client → Emotiv cihazdan EEG alır
2. Backend API → Veriyi kaydeder ve WebSocket ile yayınlar
3. Flutter App → Canlı grafik ve duygu kartlarını gösterir
