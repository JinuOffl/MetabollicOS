from sqlalchemy import Column, String, DateTime
from sqlalchemy.orm import relationship
import datetime
import uuid
from app.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    
    profile = relationship("UserProfile", back_populates="user", uselist=False)

class UserProfile(Base):
    __tablename__ = "user_profiles"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()), index=True)
    user_id = Column(String, sqlalchemy.ForeignKey("users.id"))
    diabetes_type = Column(String)
    hba1c_band = Column(String)
    cuisine_preference = Column(String)
    diet_type = Column(String)
    
    user = relationship("User", back_populates="profile")
