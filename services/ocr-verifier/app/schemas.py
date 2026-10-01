from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any

class KTMVerificationRequest(BaseModel):
    user_id: str = Field(..., description="Supabase Profile UUID")
    image_url: Optional[str] = Field(None, description="Public URL of the uploaded KTM image in Supabase Storage")
    expected_nim: Optional[str] = Field(None, description="NIM entered by user for match validation")
    expected_name: Optional[str] = Field(None, description="Student name entered by user")

class ExtractedKTMData(BaseModel):
    raw_text: str
    detected_nim: Optional[str] = None
    detected_name: Optional[str] = None
    detected_university: Optional[str] = None
    detected_faculty: Optional[str] = None
    confidence_score: float = 0.0

class KTMVerificationResponse(BaseModel):
    status: str = Field(..., description="SUCCESS / REVIEW / REJECTED")
    is_valid: bool
    match_nim: bool = False
    match_name: bool = False
    message: str
    extracted_data: ExtractedKTMData
    metadata: Dict[str, Any] = {}
