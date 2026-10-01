# 🐍 Mpus KTM OCR Verification Microservice

Microservice Python berbasis **FastAPI** untuk memvalidasi Kartu Tanda Mahasiswa (KTM) secara otomatis menggunakan Computer Vision & Regex Parser.

---

## 🚀 Fitur Utama
1. **Ekstraksi Teks KTM**: Mendeteksi NIM/NPM, Nama Mahasiswa, dan Nama Universitas/Kampus.
2. **Matching Verifikasi**: Mencocokkan data OCR dengan data input pengguna saat pendaftaran di aplikasi Mpus.
3. **Multi-Platform Deployment**:
   - **Vercel Serverless**: Siap deploy via `vercel.json` (`@vercel/python`).
   - **Koyeb / Render / Fly.io**: Siap deploy via `Dockerfile`.

---

## 📡 API Endpoints
- `GET /`: Health check & service info.
- `POST /api/v1/verify-ktm`: Verifikasi via URL gambar Supabase Storage.
- `POST /api/v1/verify-upload`: Verifikasi via direct multipart upload.

---

## 💻 Menjalankan Lokal
```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
Buka dokumentasi interaktif Swagger di `http://localhost:8000/docs`.
