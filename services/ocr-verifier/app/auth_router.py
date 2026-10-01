from fastapi import APIRouter, UploadFile, File, Form, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional, Dict, Any
import time
import secrets
import logging
import re

from app.ocr_engine import KTROcrEngine
from app.mailer import send_mpus_otp_email

logger = logging.getLogger("auth_router")
router = APIRouter(prefix="/api/v1/auth", tags=["Unified Auth & OTP"])

engine = KTROcrEngine()

# In-memory OTP storage with TTL (10 minutes)
# Format: { email: { "otp": "123456", "expires_at": float, "user_data": dict } }
otp_storage: Dict[str, Dict[str, Any]] = {}

class VerifyOtpRequest(BaseModel):
    email: str
    otp: str

class ResendOtpRequest(BaseModel):
    email: str

class AuthResponse(BaseModel):
    success: bool
    message: str
    campus_name: Optional[str] = None
    student_nim: Optional[str] = None
    email: Optional[str] = None

@router.post("/register-ktm", response_model=AuthResponse)
async def register_with_ktm(
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    nim: str = Form(...),
    phone: Optional[str] = Form(""),
    file: UploadFile = File(...)
):
    """
    1. AI Verification of KTM card with Google Gemini 2.5 Flash.
    2. NIM & legitimacy enforcement.
    3. 6-digit cryptographic OTP generation.
    4. HTML email dispatch to the student's inbox.
    """
    clean_email = email.strip().lower()
    clean_name = name.strip()
    clean_nim = nim.strip()

    try:
        contents = await file.read()
        mime_type = file.content_type or "image/jpeg"

        # 1. Run AI Gemini Verification
        gemini_result = await engine.verify_ktm_with_gemini(
            image_bytes=contents,
            mime_type=mime_type,
            expected_nim=clean_nim,
            expected_name=clean_name
        )

        if not gemini_result:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="AI Vision gagal menganalisis dokumen KTM. Pastikan foto tidak buram dan format gambar didukung."
            )

        det_nim = gemini_result.get("student_nim")
        det_name = gemini_result.get("student_name")
        det_univ = gemini_result.get("campus_name") or "Kampus Mahasiswa"
        is_valid = bool(gemini_result.get("is_valid_ktm", False))
        reason = gemini_result.get("reason", "")

        # Strict checks
        if not is_valid or not det_nim or str(det_nim).strip() in ["", "null", "None", "undefined"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=reason or "Nomor NIM tidak ditemukan pada foto KTM. Harap unggah foto KTM asli yang jelas."
            )

        # Match NIM
        clean_exp = re.sub(r'[^A-Z0-9]', '', clean_nim.upper())
        clean_det = re.sub(r'[^A-Z0-9]', '', str(det_nim).upper())
        if not ((clean_exp in clean_det) or (clean_det in clean_exp)):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"NIM pada foto KTM ({det_nim}) tidak cocok dengan NIM pendaftaran ({clean_nim})."
            )

        # 2. Generate 6-Digit Secure OTP
        otp_pin = str(secrets.randbelow(900000) + 100000)
        expires_at = time.time() + 600  # 10 minutes

        otp_storage[clean_email] = {
            "otp": otp_pin,
            "expires_at": expires_at,
            "user_data": {
                "name": clean_name,
                "email": clean_email,
                "password": password,
                "nim": clean_nim,
                "phone": phone,
                "campus_name": det_univ,
                "is_ktm_verified": True
            }
        }

        # 3. Send HTML Email
        print(f"\n=======================================================")
        print(f"🔑 [MPUS REGISTRATION OTP] Email: {clean_email}")
        print(f"🔢 [OTP CODE]: {otp_pin} (Berlaku 10 Menit)")
        print(f"👤 Nama: {clean_name} | Kampus: {det_univ} | NIM: {det_nim}")
        print(f"=======================================================\n")

        await send_mpus_otp_email(
            to_email=clean_email,
            name=clean_name,
            otp_code=otp_pin,
            campus_name=det_univ
        )

        logger.info(f"Generated OTP {otp_pin} and queued email to {clean_email}")

        return AuthResponse(
            success=True,
            message=f"KTM Terverifikasi ({det_univ}). Kode OTP telah dikirimkan ke {clean_email}.",
            campus_name=det_univ,
            student_nim=det_nim,
            email=clean_email
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in register_with_ktm: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Terjadi kesalahan pemrosesan registrasi: {str(e)}"
        )

@router.post("/verify-otp", response_model=AuthResponse)
async def verify_otp(payload: VerifyOtpRequest):
    """
    Validates the 6-digit OTP code against the backend storage.
    """
    clean_email = payload.email.strip().lower()
    clean_otp = payload.otp.strip()

    record = otp_storage.get(clean_email)
    if not record:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kode OTP tidak ditemukan atau sudah kadaluarsa. Silakan lakukan pendaftaran ulang."
        )

    if time.time() > record["expires_at"]:
        otp_storage.pop(clean_email, None)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kode OTP telah kadaluarsa. Silakan klik 'Kirim Ulang'."
        )

    if record["otp"] != clean_otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Kode OTP salah. Periksa kembali email Anda."
        )

    # Verification success
    user_data = record.get("user_data", {})
    return AuthResponse(
        success=True,
        message="Verifikasi kode OTP berhasil.",
        campus_name=user_data.get("campus_name"),
        student_nim=user_data.get("nim"),
        email=clean_email
    )

@router.post("/resend-otp", response_model=AuthResponse)
async def resend_otp(payload: ResendOtpRequest):
    """
    Generates a new 6-digit OTP and resends HTML email.
    """
    clean_email = payload.email.strip().lower()
    record = otp_storage.get(clean_email)

    name = "Mahasiswa"
    campus_name = "Kampus"
    user_data = {}

    if record:
        user_data = record.get("user_data", {})
        name = user_data.get("name", "Mahasiswa")
        campus_name = user_data.get("campus_name", "Kampus")

    otp_pin = str(secrets.randbelow(900000) + 100000)
    expires_at = time.time() + 600

    otp_storage[clean_email] = {
        "otp": otp_pin,
        "expires_at": expires_at,
        "user_data": user_data
    }

    print(f"\n=======================================================")
    print(f"🔄 [MPUS RESEND OTP] Email: {clean_email}")
    print(f"🔢 [NEW OTP CODE]: {otp_pin} (Berlaku 10 Menit)")
    print(f"=======================================================\n")

    await send_mpus_otp_email(
        to_email=clean_email,
        name=name,
        otp_code=otp_pin,
        campus_name=campus_name
    )

    return AuthResponse(
        success=True,
        message=f"Kode OTP baru telah dikirimkan ke {clean_email}.",
        campus_name=campus_name,
        email=clean_email
    )
