from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.glucose import GlucoseReadingRequest, GlucoseReadingResponse
from app.models.glucose import GlucoseReading

router = APIRouter(prefix="/glucose-reading", tags=["Glucose"])

@router.post("", response_model=GlucoseReadingResponse)
def log_glucose(request: GlucoseReadingRequest, db: Session = Depends(get_db)):
    reading = GlucoseReading(
        user_id=request.user_id,
        reading_type=request.reading_type,
        value_mgdl=request.value_mgdl
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)
    return reading
