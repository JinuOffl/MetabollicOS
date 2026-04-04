from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class GlucoseReadingRequest(BaseModel):
    user_id: str
    reading_type: str
    value_mgdl: float

class GlucoseReadingResponse(BaseModel):
    id: str
    user_id: str
    reading_type: str
    value_mgdl: float
    timestamp: datetime
    
    class Config:
        from_attributes = True
