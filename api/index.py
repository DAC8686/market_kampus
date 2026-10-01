import sys
import os

# Link services/ocr-verifier module path to Vercel Python runtime
current_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.dirname(current_dir)
ocr_service_dir = os.path.join(root_dir, "services", "ocr-verifier")

if ocr_service_dir not in sys.path:
    sys.path.insert(0, ocr_service_dir)

from app.main import app
