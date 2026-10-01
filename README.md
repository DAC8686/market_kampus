# 🎓 MPUS (Market Kampus) — Polyglot Microservices Monorepo

> **Platform Marketplace Komunitas Mahasiswa Terpercaya**  
> Mengusung konsep COD Aman Kampus & Validasi Identitas Mahasiswa (KTM) berbasis AI/OCR.

---

## 🏗️ Struktur Arsitektur Monorepo

```
/home/dac/Desktop/Mpus/
├── apps/
│   └── web-catalog/            # Web Catalog Publik (SEO) & Dashboard (Next.js 14 / Vercel)
├── database/
│   └── supabase_schema.sql     # Master Schema PostgreSQL, Triggers, RLS, Storage Buckets
├── market_kampus/              # Mobile Client Android & iOS (Flutter Clean Architecture)
│   ├── lib/
│   │   ├── core/               # Konfigurasi Supabase, Theme (#B4FFF9), & Constants
│   │   ├── data/               # Models (Type-Safe JSON) & Services (API, Storage, FCM, OCR)
│   │   └── features/           # Feature-First UI (Auth, Catalog, Profile, Splash)
│   └── assets/                 # Logo SVG & App Icons
└── services/
    └── ocr-verifier/           # Python FastAPI Microservice (Validasi KTM, Regex NIM/Kampus)
        ├── app/                # OCR Engine, Preprocessing, FastAPI Endpoints
        ├── Dockerfile          # Koyeb / Railway Ready
        └── vercel.json         # Vercel Serverless Ready
```

---

## ⚡ Setup & Cara Menjalankan

### 1. Database (Supabase)
- Buka dashboard project di [Supabase.com](https://supabase.com).
- Masuk ke **SQL Editor** dan salin isi [supabase_schema.sql](file:///home/dac/Desktop/Mpus/database/supabase_schema.sql).
- Jalankan skrip. Seluruh tabel (`profiles`, `products`, `orders`, `reviews`), triggers rating, auto-profile creation, dan storage bucket policies akan terkonfigurasi secara otomatis.

### 2. Python OCR Microservice (`services/ocr-verifier`)
```bash
cd /home/dac/Desktop/Mpus/services/ocr-verifier
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
- API Docs: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

### 3. Mobile Client Flutter (`market_kampus`)
```bash
cd /home/dac/Desktop/Mpus/market_kampus
flutter pub get
flutter run
```

### 4. Web Catalog (`apps/web-catalog`)
```bash
cd /home/dac/Desktop/Mpus/apps/web-catalog
npm install
npm run dev
```

---

## 💎 Konsep & Keunggulan
1. **COD Only + Digital Payment Companion**:
   - Menghubungkan pembeli dan penjual di area kampus yang sama.
   - Dilengkapi generator jadwal COD dan opsi pembayaran instan via QRIS / E-Wallet.
2. **KTM AI OCR Verifier**:
   - Memastikan hanya mahasiswa asli kampus bersangkutan yang dapat bertransaksi.
3. **Clean Code & Anti-Boncos Monorepo**:
   - Struktur modular berstandar industri dengan pemisahan peran yang tegas antara backend serverless, microservice cerdas, dan aplikasi client yang responsif.
