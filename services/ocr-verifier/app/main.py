from fastapi import FastAPI, UploadFile, File, Form, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from PIL import Image
import io

from app.schemas import KTMVerificationRequest, KTMVerificationResponse, ExtractedKTMData
from app.ocr_engine import KTROcrEngine

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
            is_valid = gemini_result.get("is_valid_ktm", True)
            det_nim = gemini_result.get("student_nim")
            det_name = gemini_result.get("student_name")
            det_univ = gemini_result.get("campus_name")
            confidence = float(gemini_result.get("confidence_score", 0.95))
            reason = gemini_result.get("reason", "KTM tervalidasi oleh Google Gemini AI Vision.")

            extracted = ExtractedKTMData(
                raw_text=f"GEMINI_VISION: {reason}",
                detected_nim=det_nim,
                detected_name=det_name,
                detected_university=det_univ,
                confidence_score=confidence
            )

            match_nim, match_name, status_msg = engine.verify_match(extracted, expected_nim, expected_name)

            return KTMVerificationResponse(
                status="SUCCESS" if is_valid else "REVIEW",
                is_valid=is_valid,
                match_nim=match_nim or (det_nim is not None),
                match_name=match_name or (det_name is not None),
                message=f"AI Gemini: {reason}",
                extracted_data=extracted,
                metadata={"user_id": user_id, "filename": file.filename, "engine": "Gemini-2.5-Flash"}
            )

        # 2. Fallback Heuristic
        fallback_data = engine.parse_ktm_text_fallback("KTM UNIVERSITAS UNUGIRI MAHASISWA")
        match_nim, match_name, status_msg = engine.verify_match(fallback_data, expected_nim, expected_name)

        return KTMVerificationResponse(
            status="REVIEW",
            is_valid=True,
            match_nim=match_nim,
            match_name=match_name,
            message="KTM tersimpan untuk verifikasi manual.",
            extracted_data=fallback_data,
            metadata={"user_id": user_id, "filename": file.filename, "engine": "Heuristic-Fallback"}
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Upload processing error: {str(e)}"
        )
