from sqlalchemy import Column, String, Float, DateTime, ForeignKey
import datetime
import uuid
from app.database import Base

class GlucoseReading(Base):
    __tablename__ = "glucose_readings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    reading_type = Column(String) # 'fasting', 'post-prandial', 'random'
    value_mgdl = Column(Float)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
