import sys
import os

# Add parent directory to sys.path so app module is discoverable on Vercel serverless
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.main import app
