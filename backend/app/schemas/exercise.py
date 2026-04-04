from pydantic import BaseModel

class ExerciseResponse(BaseModel):
    id: str
    name: str
    type: str
    duration: int
    met: float
    glucose_benefit: float
    burnout_cost: float
    timing: str

    class Config:
        from_attributes = True
