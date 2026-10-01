# 🎓 MPUS (Market Kampus) — Enterprise Microservices Monorepo

> **Platform Marketplace Komunitas Mahasiswa Terpercaya**  
> Mengusung konsep COD Aman Kampus & Validasi Identitas Mahasiswa (KTM) berbasis Google Gemini 3.1 Flash Lite AI.

---

## 🏗️ Struktur Arsitektur Monorepo

```text
/home/dac/Desktop/Mpus/
├── 📱 apps/
│   ├── mobile/                 # Mobile App Android & iOS (Flutter Clean Architecture)
│   │   ├── lib/
│   │   │   ├── core/           # Konfigurasi Supabase, Theme (#B4FFF9), & Constants
│   │   │   ├── data/           # Models (Type-Safe JSON) & Services (API, Storage, FCM, OCR)
│   │   │   └── features/       # Feature-First UI (Auth, Catalog, Profile, Splash)
│   │   └── assets/             # Logo SVG & App Icons
│   └── web/                    # Web Catalog Publik & Landing Page
│
├── ⚡ services/
│   └── ocr-verifier/           # Python FastAPI + Google Gemini 3.1 Flash Lite AI Engine
│       ├── app/                # AI Vision Engine, Schemas, FastAPI Endpoints
│       └── requirements.txt
│
├── 🗄️ database/
│   └── supabase_schema.sql     # Master Schema PostgreSQL, Triggers, RLS, Storage Buckets
│
├── 🌐 api/
│   └── index.py                # Vercel Serverless Python Gateway
│
├── vercel.json                 # Konfigurasi Single Routing Vercel
├── requirements.txt            # Dependensi Vercel Build
├── .gitignore                  # Monorepo Clean Ignores
└── README.md
```

---

## ⚡ Setup & Cara Menjalankan

### 1. Database (Supabase)
- Buka dashboard project di [Supabase.com](https://supabase.com).
- Masuk ke **SQL Editor** dan salin isi `database/supabase_schema.sql`.
- Jalankan skrip. Seluruh tabel (`profiles`, `products`, `orders`, `reviews`), triggers rating, auto-profile creation, dan storage bucket policies (`ktm-documents`, `product-images`, dll) akan terkonfigurasi secara otomatis.

### 2. Python AI OCR Microservice (`services/ocr-verifier`)
```bash
cd services/ocr-verifier
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
- API Docs: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

### 3. Mobile Client Flutter (`apps/mobile`)
```bash
cd apps/mobile
flutter pub get
flutter run
```

---

## 💎 Konsep & Keunggulan
1. **COD Only + Digital Payment Companion**:
   - Menghubungkan pembeli dan penjual di area kampus yang sama.
   - Opsi pembayaran instan via QRIS / E-Wallet.
2. **KTM Google Gemini 3.1 Flash Lite AI**:
   - Memastikan hanya mahasiswa asli kampus bersangkutan yang dapat bertransaksi.
   - Ekstraksi otomatis instan untuk NIM, Nama, dan Universitas.
3. **Vercel Serverless Single Domain**:
   - Seluruh backend AI berjalan di `https://mpus.daczdev.id`.
