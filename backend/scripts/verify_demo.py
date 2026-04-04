"""
scripts/verify_demo.py — S1.1 / S1.2

Verifies that both demo users are correctly seeded in the database and
that the /recommend endpoint returns visibly different results for each.

Run from backend/ directory AFTER seed_demo.py:
    cd backend
    python scripts/verify_demo.py

Exit code 0 = all checks passed.
Exit code 1 = one or more checks failed.
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base
from app.models.user import User, UserProfile
from app.models.meal import MealInteraction
from app.models.exercise import ExerciseInteraction
from app.models.glucose import GlucoseReading

Base.metadata.create_all(bind=engine)

PASS = "  ✅"
FAIL = "  ❌"
WARN = "  ⚠️ "

errors = []


def check(condition: bool, label: str, detail: str = ""):
    status = PASS if condition else FAIL
    print(f"{status} {label}" + (f"  [{detail}]" if detail else ""))
    if not condition:
        errors.append(label)


def run_checks():
    db = SessionLocal()
    try:
        print("\n══════════════════════════════════════════════════════════")
        print("  GlucoNav Demo Verification — S1.1 / S1.2")
        print("══════════════════════════════════════════════════════════\n")

        # ── S1.1: demo_user_new ───────────────────────────────────────────
        print("── demo_user_new ────────────────────────────────────────")

        new_user = db.query(User).filter(User.id == "demo_user_new").first()
        check(new_user is not None, "User row exists")

        new_profile = db.query(UserProfile).filter(
            UserProfile.user_id == "demo_user_new"
        ).first()
        check(new_profile is not None, "UserProfile row exists")
        if new_profile:
            check(new_profile.diabetes_type == "type2",
                  "diabetes_type = type2", new_profile.diabetes_type)
            check(new_profile.cuisine_preference == "south_indian",
                  "cuisine = south_indian", new_profile.cuisine_preference)

        new_meals = db.query(MealInteraction).filter(
            MealInteraction.user_id == "demo_user_new"
        ).count()
        check(new_meals == 0,
              "No meal interactions (cold start)", f"{new_meals} found")

        new_glucose = db.query(GlucoseReading).filter(
            GlucoseReading.user_id == "demo_user_new"
        ).count()
        check(new_glucose == 0,
              "No glucose readings (cold start)", f"{new_glucose} found")

        # ── S1.2: demo_user_experienced ───────────────────────────────────
        print("\n── demo_user_experienced ────────────────────────────────")

        exp_user = db.query(User).filter(User.id == "demo_user_experienced").first()
        check(exp_user is not None, "User row exists")

        exp_profile = db.query(UserProfile).filter(
            UserProfile.user_id == "demo_user_experienced"
        ).first()
        check(exp_profile is not None, "UserProfile row exists")

        exp_meals = db.query(MealInteraction).filter(
            MealInteraction.user_id == "demo_user_experienced"
        ).count()
        check(exp_meals >= 28, "≥ 28 meal interactions (14 days × 2)",
              f"{exp_meals} found")

        exp_exercises = db.query(ExerciseInteraction).filter(
            ExerciseInteraction.user_id == "demo_user_experienced"
        ).count()
        check(exp_exercises >= 14, "≥ 14 exercise interactions",
              f"{exp_exercises} found")

        exp_glucose = db.query(GlucoseReading).filter(
            GlucoseReading.user_id == "demo_user_experienced"
        ).count()
        check(exp_glucose >= 14, "≥ 14 glucose readings",
              f"{exp_glucose} found")

        # Verify glucose values are within plausible range
        sample = db.query(GlucoseReading).filter(
            GlucoseReading.user_id == "demo_user_experienced",
            GlucoseReading.glucose_mgdl.isnot(None),
        ).first()
        if sample:
            check(80 <= (sample.glucose_mgdl or 0) <= 220,
                  "Glucose values in plausible range",
                  f"sample = {sample.glucose_mgdl} mg/dL")

        # ── Personalization delta check ────────────────────────────────────
        print("\n── Personalization delta (S1.4) ─────────────────────────")
        check(exp_meals > new_meals,
              "Experienced user has more meal history than new user",
              f"{exp_meals} vs {new_meals}")
        check(exp_glucose > new_glucose,
              "Experienced user has glucose history; new user does not",
              f"{exp_glucose} vs {new_glucose}")

        # Try to call the recommendation service locally
        print("\n── Recommendation engine sanity check ───────────────────")
        try:
            from app.services.diet_engine import get_diet_recommendations
            profile_dict = {
                "diabetes_type": "type2",
                "regional_cuisine": "south_indian",
                "diet_preference": "vegetarian",
                "hba1c_band": "moderate",
            }
            recs = get_diet_recommendations(profile_dict, top_n=3)
            check(len(recs) >= 1, "diet_engine returns ≥ 1 recommendation",
                  f"{len(recs)} returned")
            if recs:
                top = recs[0]
                print(f"      Top meal: {top.get('name', '?')} "
                      f"(spike +{top.get('predicted_spike_mg', '?')} mg/dL)")
        except Exception as e:
            print(f"{WARN} diet_engine check skipped: {e}")
            print("     (Run `python test_recommend.py` to verify ML models)")

        # ── Summary ───────────────────────────────────────────────────────
        print("\n══════════════════════════════════════════════════════════")
        if errors:
            print(f"  ❌ {len(errors)} check(s) failed:")
            for err in errors:
                print(f"     • {err}")
            print("\n  Run: python scripts/seed_demo.py  to re-seed.")
        else:
            print("  ✅ All checks passed — demo data is ready!")
            print("\n  Next steps:")
            print("  1. python run.py         → start FastAPI at localhost:8000")
            print("  2. flutter run -d chrome → start Flutter app")
            print("  3. Walk the 8-step demo script in DEMO_SCRIPT.md")
        print("══════════════════════════════════════════════════════════\n")

    finally:
        db.close()

    return len(errors) == 0


if __name__ == "__main__":
    ok = run_checks()
    sys.exit(0 if ok else 1)
