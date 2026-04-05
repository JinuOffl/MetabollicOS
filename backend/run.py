import uvicorn
import os
from dotenv import load_dotenv
from app.database import engine, Base

# Load .env before anything else — ensures VISION_USE_STUB, GOOGLE_AI_KEY, etc. are set
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

if __name__ == "__main__":
    # Create tables
    Base.metadata.create_all(bind=engine)

    print(f"[run.py] VISION_USE_STUB = {os.getenv('VISION_USE_STUB', 'NOT SET')}")
    print(f"[run.py] GOOGLE_AI_KEY   = {'SET' if os.getenv('GOOGLE_AI_KEY') else 'NOT SET'}")

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
