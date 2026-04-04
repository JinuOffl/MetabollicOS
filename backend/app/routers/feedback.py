from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.feedback import FeedbackRequest, FeedbackResponse
from app.models.meal import MealInteraction
from app.models.exercise import ExerciseInteraction

router = APIRouter(prefix="/feedback", tags=["Feedback"])


@router.post("", response_model=FeedbackResponse)
def submit_feedback(request: FeedbackRequest, db: Session = Depends(get_db)):
    """
    Log a meal or exercise interaction for model refinement + burnout tracking.
    user_id is required — burnout_service queries interactions by user.
    """
    if request.item_type == "meal":
        interaction = MealInteraction(
            user_id=request.user_id,
            meal_id=request.item_id,
            interaction_type=request.interaction_type,
        )
        db.add(interaction)
    elif request.item_type == "exercise":
        interaction = ExerciseInteraction(
            user_id=request.user_id,
            exercise_id=request.item_id,
            interaction_type=request.interaction_type,
        )
        db.add(interaction)

    db.commit()
    return FeedbackResponse(
        status="success",
        user_id=request.user_id,
        item_id=request.item_id,
    )
