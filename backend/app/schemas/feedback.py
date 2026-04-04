from pydantic import BaseModel

class FeedbackRequest(BaseModel):
    item_id: str
    item_type: str # 'meal', 'exercise'
    interaction_type: str # 'logged', 'ignored'

class FeedbackResponse(BaseModel):
    status: str
