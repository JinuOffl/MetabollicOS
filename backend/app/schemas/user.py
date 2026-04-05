from pydantic import BaseModel
from typing import Optional

class OnboardRequest(BaseModel):
    diabetes_type: str
    hba1c_band: str
    cuisine_preference: str
    diet_type: str
    age: Optional[int] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    gender: Optional[str] = None
    goal: Optional[str] = None
    activity_level: Optional[str] = None

class UserProfileData(BaseModel):
    diabetes_type: str
    hba1c_band: str
    cuisine_preference: str
    diet_type: str
    age: Optional[int] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    gender: Optional[str] = None
    goal: Optional[str] = None
    activity_level: Optional[str] = None

class UserResponse(BaseModel):
    user_id: str
    profile: UserProfileData

    class Config:
        from_attributes = True
