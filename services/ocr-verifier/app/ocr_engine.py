import os
import re
import io
import json
import base64
import httpx
from PIL import Image, ImageEnhance, ImageFilter
from typing import Optional, Dict, Any, Tuple
from dotenv import load_dotenv
from app.schemas import ExtractedKTMData

load_dotenv()

class KTROcrEngine:
    """
    AI Vision & OCR Engine powered by Google Gemini AI (Multimodal Vision)
    with local regex heuristic fallback for Indonesian Student Identity Cards (KTM).
    """

    def __init__(self):
        self.gemini_api_key = os.getenv("GEMINI_API_KEY", "")
        self.gemini_model = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

    # Regex pattern fallback for Indonesian NIM
    NIM_PATTERN = re.compile(r'(?:NIM|NPM|NRP|NOMOR\s+INDUK|NO\s+MAHASISWA)[:\s\.\-]*([A-Z0-9\.\-]{6,16})', re.IGNORECASE)
    FALLBACK_NUMERIC_NIM = re.compile(r'\b\d{6,16}\b')

    UNIVERSITY_KEYWORDS = [
        "UNIVERSITAS", "INSTITUT", "POLITEKNIK", "SEKOLAH TINGGI", "AKADEMI",
        "UNUGIRI", "UGM", "ITB", "UI", "UNAIR", "ITS", "UNESA", "UNDIP", "UB", "UNY", "UIN"
    ]

    async def fetch_image_bytes(self, image_url: str) -> bytes:
        """Download image bytes from public URL or Supabase Storage."""
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(image_url)
            resp.raise_for_status()
            return resp.content

    async def verify_ktm_with_gemini(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        expected_nim: Optional[str] = None,
        expected_name: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Use Google Gemini AI Vision (Multimodal) to extract and validate Student Identity Card (KTM).
        """
        if not self.gemini_api_key:
            return None

        b64_image = base64.b64encode(image_bytes).decode("utf-8")
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.gemini_model}:generateContent?key={self.gemini_api_key}"

        prompt = (
            "Kamu adalah AI Vision Expert Validator Kartu Tanda Mahasiswa (KTM) perguruan tinggi di Indonesia untuk platform MPUS.\n"
            "Tugasmu: Analisis dan baca foto kartu ini dengan teliti.\n\n"
            "PANDUAN ANALISIS:\n"
            "1. Kartu Tanda Mahasiswa (KTM) di Indonesia memiliki banyak variasi desain (KTM cetak standar, KTM combo Debit/ATM BNI/Mandiri/BRI/BSI, KTM barcode/smartcard, hingga KTM digital resmi kampus).\n"
            "2. Baca secara cermat seluruh teks pada kartu, terutama:\n"
            "   - Nama Mahasiswa\n"
            "   - Nomor Induk Mahasiswa (NIM / NPM / NRP / NIRM / No Mahasiswa / No Pokok / Student ID)\n"
            "   - Nama Perguruan Tinggi / Universitas / Institut / Politeknik / STIKES / Akademi\n"
            "   - Fakultas / Program Studi (jika ada)\n"
            f"{f'3. Periksa kecocokan nomor NIM dengan input pendaftar: \"{expected_nim}\". Abaikan perbedaan tanda baca seperti titik (.), strip (-), spasi, atau prefix huruf.' if expected_nim else ''}\n"
            "4. Jika kartu merupakan KTM yang sah dan memiliki nomor NIM/identitas mahasiswa yang dapat diidentifikasi, set `is_valid_ktm: true`.\n"
            "5. Jika foto jelas-jelas BUKAN kartu identitas mahasiswa (misal: foto pemandangan, foto selfie tanpa kartu, KTP non-mahasiswa, struk belanja), set `is_valid_ktm: false`.\n\n"
            "Berikan output HANYA dalam format JSON valid berikut:\n"
            "{\n"
            '  "is_valid_ktm": true,\n'
            '  "student_name": "Nama lengkap mahasiswa jika terbaca (atau null)",\n'
            '  "student_nim": "NIM/NPM mahasiswa (hanya alfanumerik tanpa spasi/tanda baca)",\n'
            '  "campus_name": "Nama universitas / kampus / perguruan tinggi",\n'
            '  "faculty_major": "Fakultas / Program Studi jika tertera",\n'
            '  "confidence_score": 0.95,\n'
            '  "reason": "Penjelasan singkat hasil pembacaan KTM"\n'
            "}"
        )

        payload = {
            "contents": [{
                "parts": [
                    {"text": prompt},
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": b64_image
                        }
                    }
                ]
            }],
            "generationConfig": {
                "temperature": 0.1,
                "response_mime_type": "application/json"
            }
        }

        try:
            async with httpx.AsyncClient(timeout=25.0) as client:
                response = await client.post(url, json=payload)
                if response.status_code == 200:
                    data = response.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        raw_json_str = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "{}")
                        # Clean if there's markdown wrapper
                        raw_json_str = re.sub(r'^```json\s*', '', raw_json_str.strip())
                        raw_json_str = re.sub(r'\s*```$', '', raw_json_str.strip())
                        parsed = json.loads(raw_json_str)
                        print(f"[Gemini OCR Success] Result: {parsed}")
                        return parsed
                else:
                    print(f"[Gemini OCR Error] HTTP {response.status_code}: {response.text}")
        except Exception as e:
            print(f"[Gemini OCR Warning] Vision API error: {e}")

        return None

    def parse_ktm_text_fallback(self, raw_text: str) -> ExtractedKTMData:
        """
        Fallback parser using regex heuristics if AI is offline.
        """
        lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
        clean_text = " ".join(lines).upper()

        detected_nim = None
        detected_name = None
        detected_univ = None

        match_nim = self.NIM_PATTERN.search(clean_text)
        if match_nim:
            detected_nim = re.sub(r'[^A-Z0-9]', '', match_nim.group(1).upper())
        else:
            fallback_match = self.FALLBACK_NUMERIC_NIM.search(clean_text)
            if fallback_match:
                detected_nim = fallback_match.group(0)

        for univ in self.UNIVERSITY_KEYWORDS:
            if univ in clean_text:
                detected_univ = univ
                break

        name_match = re.search(r'(?:NAMA|NAME)[:\s\.\-]*([A-Z\s\.\,\']{3,35})', clean_text, re.IGNORECASE)
        if name_match:
            detected_name = name_match.group(1).strip()

        confidence = 0.5
        if detected_univ: confidence += 0.25
        if detected_nim: confidence += 0.25

        return ExtractedKTMData(
            raw_text=raw_text,
            detected_nim=detected_nim,
            detected_name=detected_name,
            detected_university=detected_univ,
            confidence_score=min(confidence, 1.0)
        )

    def verify_match(
        self,
        extracted: ExtractedKTMData,
        expected_nim: Optional[str] = None,
        expected_name: Optional[str] = None
    ) -> Tuple[bool, bool, str]:
        """
        Compare extracted data against user submitted NIM and Name.
        """
        match_nim = False
        match_name = False

        if expected_nim and extracted.detected_nim:
            clean_expected = re.sub(r'[^A-Z0-9]', '', expected_nim.upper())
            clean_detected = re.sub(r'[^A-Z0-9]', '', extracted.detected_nim.upper())
            match_nim = (clean_expected in clean_detected) or (clean_detected in clean_expected)

        if expected_name and extracted.detected_name:
            words_expected = set(expected_name.upper().split())
            words_detected = set(extracted.detected_name.upper().split())
            if len(words_expected.intersection(words_detected)) >= max(1, len(words_expected) // 2):
                match_name = True

        if match_nim or extracted.confidence_score >= 0.75:
            status_msg = "KTM Mahasiswa valid dan terverifikasi otomatis oleh AI."
        else:
            status_msg = "Foto KTM tersimpan untuk peninjauan admin."

        return match_nim, match_name, status_msg
