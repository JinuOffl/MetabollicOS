import uvicorn
import os
from app.database import engine, Base
# Import models here so they are registered with Base
# from app.models import user, meal, exercise, glucose

if __name__ == "__main__":
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
