from fastapi import FastAPI, UploadFile, File, Form, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from PIL import Image
import io

from app.schemas import KTMVerificationRequest, KTMVerificationResponse, ExtractedKTMData
from app.ocr_engine import KTROcrEngine
from app.auth_router import router as auth_router

app = FastAPI(
    title="Mpus KTM Verification & Google Gemini AI Microservice",
    description="Dedicated AI microservice for Indonesian Student Identity Card (KTM) validation for Mpus (Market Kampus)",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for Mobile & Web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth_router)

engine = KTROcrEngine()

@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "Mpus KTM Gemini AI Verifier",
        "status": "ONLINE",
        "version": "2.1.0",
        "ai_engine": "Google Gemini 3.1 Flash Lite",
        "owner": "DACZDev (Pak Bos Dimas)"
    }

@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy", "service": "ocr-verifier", "ai_ready": True}

@app.post("/api/v1/verify-upload", response_model=KTMVerificationResponse, tags=["KTM Verification"])
async def verify_upload(
    user_id: Optional[str] = Form("guest"),
    expected_nim: Optional[str] = Form(None),
    expected_name: Optional[str] = Form(None),
    file: UploadFile = File(...)
):
    """
    Direct file upload verification powered by Google Gemini 2.5 Flash AI Vision.
    """
    try:
        contents = await file.read()
        mime_type = file.content_type or "image/jpeg"

        # 1. Primary: Run Google Gemini 2.5 Flash Vision
        gemini_result = await engine.verify_ktm_with_gemini(
            image_bytes=contents,
            mime_type=mime_type,
            expected_nim=expected_nim,
            expected_name=expected_name
        )

        if gemini_result:
            det_nim = gemini_result.get("student_nim")
            det_name = gemini_result.get("student_name")
            det_univ = gemini_result.get("campus_name")
            confidence = float(gemini_result.get("confidence_score", 0.95))
            reason = gemini_result.get("reason", "KTM tervalidasi oleh Google Gemini AI Vision.")

            is_valid = bool(gemini_result.get("is_valid_ktm", False))

            # 🛡️ STRICT VALIDATION 1: NIM WAJIB ADA
            if not det_nim or str(det_nim).strip() in ["", "null", "None", "undefined"]:
                is_valid = False
                det_nim = None
                reason = "Nomor NIM tidak terdeteksi pada foto KTM. Harap unggah foto KTM yang memuat nomor NIM dengan jelas."

            # 🛡️ STRICT VALIDATION 2: NIM WAJIB COCOK DENGAN expected_nim
            match_nim = False
            if det_nim and expected_nim:
                import re
                clean_exp = re.sub(r'[^A-Z0-9]', '', str(expected_nim).upper())
                clean_det = re.sub(r'[^A-Z0-9]', '', str(det_nim).upper())
                match_nim = (clean_exp in clean_det) or (clean_det in clean_exp)
                if not match_nim:
                    is_valid = False
                    reason = f"NIM pada foto KTM ({det_nim}) tidak sesuai dengan NIM yang Anda daftarkan ({expected_nim})."
            elif det_nim:
                match_nim = True

            extracted = ExtractedKTMData(
                raw_text=f"GEMINI_VISION: {reason}",
                detected_nim=det_nim,
                detected_name=det_name,
                detected_university=det_univ,
                confidence_score=confidence
            )

            return KTMVerificationResponse(
                success=is_valid,
                status="VERIFIED" if is_valid else "REJECTED",
                is_valid=is_valid,
                match_nim=match_nim,
                match_name=(det_name is not None),
                student_name=det_name,
                student_nim=det_nim,
                campus_name=det_univ,
                message=f"AI Gemini: {reason}",
                error_message=reason if not is_valid else None,
                extracted_data=extracted,
                metadata={"user_id": user_id, "filename": file.filename, "engine": "Gemini-2.5-Flash"}
            )

        # 2. Fallback jika Gemini API tidak merespons
        fallback_data = engine.parse_ktm_text_fallback("KTM UNIVERSITAS MAHASISWA")
        return KTMVerificationResponse(
            success=False,
            status="REJECTED",
            is_valid=False,
            match_nim=False,
            match_name=False,
            student_name=None,
            student_nim=None,
            campus_name=None,
            message="KTM gagal divalidasi oleh AI. Pastikan foto kartu tidak buram dan nomor NIM terlihat jelas.",
            error_message="KTM gagal divalidasi oleh AI. Pastikan foto kartu tidak buram dan nomor NIM terlihat jelas.",
            extracted_data=fallback_data,
            metadata={"user_id": user_id, "filename": file.filename, "engine": "Fallback-Reject"}
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Upload processing error: {str(e)}"
        )
