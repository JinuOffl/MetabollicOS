from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.meal import MealInteraction
from app.models.exercise import ExerciseInteraction
from app.schemas.feedback import FeedbackRequest, FeedbackResponse

router = APIRouter(prefix="/feedback", tags=["Feedback"])

@router.post("", response_model=FeedbackResponse)
def submit_feedback(request: FeedbackRequest, db: Session = Depends(get_db)):
    if request.item_type == "meal":
        interaction = MealInteraction(meal_id=request.item_id, interaction_type=request.interaction_type)
        db.add(interaction)
    elif request.item_type == "exercise":
        interaction = ExerciseInteraction(exercise_id=request.item_id, interaction_type=request.interaction_type)
        db.add(interaction)
        
    db.commit()
    return FeedbackResponse(status="success")
