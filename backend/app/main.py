from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import users, recommendations, feedback, glucose, meals, exercises, vision

Base.metadata.create_all(bind=engine)

app = FastAPI(title="GlucoNav API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(recommendations.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")
app.include_router(glucose.router, prefix="/api/v1")
app.include_router(meals.router, prefix="/api/v1")
app.include_router(exercises.router, prefix="/api/v1")
app.include_router(vision.router, prefix="/api/v1")   # K4.3 — Vision AI

@app.get("/")
async def root():
    return {"message": "Welcome to GlucoNav API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}
 
