from pydantic import BaseModel
from typing import Optional


class FeedbackRequest(BaseModel):
    user_id: str
    item_id: str
    item_type: str          # "meal" | "exercise"
    interaction_type: str   # "completed" | "skipped" | "logged"


class FeedbackResponse(BaseModel):
    status: str
    user_id: Optional[str] = None
    item_id: Optional[str] = None
