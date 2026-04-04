from sqlalchemy import Column, String, Float, DateTime, ForeignKey
import datetime
import uuid
from app.database import Base


class GlucoseReading(Base):
    __tablename__ = "glucose_readings"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)
    reading_type = Column(String, nullable=True)  # "fasting" | "post_prandial" | "random"
    glucose_mgdl = Column(Float, nullable=True)   # primary field name (alias: value_mgdl)
    value_mgdl = Column(Float, nullable=True)     # legacy alias — same data, both stored
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
