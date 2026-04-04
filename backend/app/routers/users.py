from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User, UserProfile
from app.schemas.user import OnboardRequest, UserResponse, UserProfileData

router = APIRouter(prefix="/users", tags=["Users"])

@router.post("/onboard", response_model=UserResponse)
def onboard_user(request: OnboardRequest, db: Session = Depends(get_db)):
    db_user = User()
    db.add(db_user)
    db.flush()
    
    db_profile = UserProfile(
        user_id=db_user.id,
        diabetes_type=request.diabetes_type,
        hba1c_band=request.hba1c_band,
        cuisine_preference=request.cuisine_preference,
        diet_type=request.diet_type
    )
    db.add(db_profile)
    db.commit()
    db.refresh(db_user)
    db.refresh(db_profile)
    
    return UserResponse(
        user_id=db_user.id,
        profile=UserProfileData(
            diabetes_type=db_profile.diabetes_type,
            hba1c_band=db_profile.hba1c_band,
            cuisine_preference=db_profile.cuisine_preference,
            diet_type=db_profile.diet_type
        )
    )
