from pydantic import BaseModel, model_validator
from typing import Optional
from datetime import datetime


class GlucoseReadingRequest(BaseModel):
    user_id: str
    reading_type: Optional[str] = "random"  # "fasting" | "post_prandial" | "random"
    # Accept either field name — Flutter sends glucose_mgdl; legacy code sends value_mgdl
    glucose_mgdl: Optional[float] = None
    value_mgdl: Optional[float] = None

    @model_validator(mode="after")
    def resolve_glucose(self):
        """Ensure at least one of glucose_mgdl / value_mgdl is provided."""
        val = self.glucose_mgdl or self.value_mgdl
        if val is None:
            raise ValueError("Provide glucose_mgdl or value_mgdl")
        # Normalise: set both to the resolved value
        self.glucose_mgdl = val
        self.value_mgdl = val
        return self


class GlucoseReadingResponse(BaseModel):
    id: str
    user_id: str
    reading_type: Optional[str] = None
    glucose_mgdl: Optional[float] = None
    value_mgdl: Optional[float] = None
    timestamp: datetime

    class Config:
        from_attributes = True
