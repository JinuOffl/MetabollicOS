from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey
from sqlalchemy.orm import relationship
import datetime
import uuid
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    email = Column(String, nullable=True, unique=True)
    name = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    profile = relationship("UserProfile", back_populates="user", uselist=False)


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, ForeignKey("users.id"), index=True)

    # Diabetes fields
    diabetes_type = Column(String, nullable=True)       # "type1" | "type2" | "prediabetes"
    hba1c_band = Column(String, nullable=True)          # "controlled" | "moderate" | "uncontrolled"
    cuisine_preference = Column(String, nullable=True)  # "south_indian" | "north_indian" | ...
    diet_type = Column(String, nullable=True)            # "vegetarian" | "vegan" | "non_vegetarian"

    # Physical profile (optional — used for richer personalization)
    age = Column(Integer, nullable=True)
    weight_kg = Column(Float, nullable=True)
    height_cm = Column(Float, nullable=True)

    user = relationship("User", back_populates="profile")
