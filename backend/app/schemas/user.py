from pydantic import BaseModel

class OnboardRequest(BaseModel):
    diabetes_type: str
    hba1c_band: str
    cuisine_preference: str
    diet_type: str

class UserProfileData(BaseModel):
    diabetes_type: str
    hba1c_band: str
    cuisine_preference: str
    diet_type: str

class UserResponse(BaseModel):
    user_id: str
    profile: UserProfileData

    class Config:
        from_attributes = True
