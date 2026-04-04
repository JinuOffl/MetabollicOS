"""
test_recommend.py
-----------------
Phase 1 Verification Script

Calls the diet and exercise engines WITHOUT needing FastAPI running.
Prints top-3 meals + exercises for two test personas:
  1. new_user        — cold-start, typical Type 2 profile
  2. experienced_user — same profile but with challenging context (poor sleep,
                        high burnout, elevated glucose)

Usage (from backend/ directory with venv active):
    python test_recommend.py

Expected output:
  ✅ top-3 meals + top-3 exercises for BOTH users, no errors.
  💡 experienced_user should show different recommendations from new_user
     (context re-ranking in action).
"""

import sys
from pathlib import Path

# Ensure backend/ is on the Python path so 'app' is importable
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.services.diet_engine import get_diet_recommendations
from app.services.exercise_engine import get_exercise_recommendations


# ── Test personas ──────────────────────────────────────────────────────────────

NEW_USER_PROFILE = {
    "diabetes_type":    "type2",
    "diet_preference":  "vegetarian",
    "regional_cuisine": "south_indian",
    "age_band":         "40s",
    "baseline_hba1c":   8.2,
    "thinfat_flag":     "True",
    "activity_level":   "sedentary",
}

NEW_USER_CONTEXT = {
    "sleep_score":     0.85,
    "current_glucose": 115.0,
    "meal_type":       "breakfast",
    "post_meal":       False,
    "burnout_score":   2.0,
}

EXPERIENCED_USER_PROFILE = {
    "diabetes_type":    "type2",
    "diet_preference":  "vegetarian",
    "regional_cuisine": "south_indian",
    "age_band":         "40s",
    "baseline_hba1c":   8.2,
    "thinfat_flag":     "True",
    "activity_level":   "sedentary",
}

EXPERIENCED_USER_CONTEXT = {
    "sleep_score":     0.35,   # poor sleep → sleep penalty active
    "current_glucose": 195.0,  # elevated → glucose penalty active
    "meal_type":       "breakfast",
    "post_meal":       True,   # 20 min after meal
    "burnout_score":   8.5,    # high burnout → HIIT/strength filtered out
}


# ── Printer ────────────────────────────────────────────────────────────────────

def _divider(title: str) -> None:
    line = "─" * 60
    print(f"\n{line}")
    print(f"  {title}")
    print(line)


def _print_meals(meals: list) -> None:
    if not meals:
        print("  ⚠  No meal recommendations returned!")
        return
    for i, m in enumerate(meals, 1):
        veg = "🥦" if m["is_vegetarian"] else "🍗"
        print(
            f"  {i}. {veg} {m['name']} ({m['cuisine']})\n"
            f"     Spike: ~{m['predicted_spike_mg']} mg/dL | "
            f"Type: {m['meal_type']} | Score: {m['score']:.3f}\n"
            f"     💡 {m['reason']}"
        )


def _print_exercises(exercises: list) -> None:
    if not exercises:
        print("  ⚠  No exercise recommendations returned!")
        return
    for i, e in enumerate(exercises, 1):
        print(
            f"  {i}. 🏃 {e['name']} ({e['exercise_type']}, {e['duration_min']} min)\n"
            f"     Glucose drop: ~{e['glucose_drop_mg']} mg/dL | "
            f"Burnout cost: {e['burnout_cost']}/10 | "
            f"Timing: {e['timing']}\n"
            f"     💡 {e['reason']}"
        )


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    print("\n🩺 GlucoNav — Phase 1 Recommendation Engine Test")
    print("=" * 60)

    # ── New user (cold start) ──────────────────────────────────────────────────
    _divider("👤 NEW USER  (cold start — no interaction history)")

    print("\n[Meals — Breakfast]")
    new_meals = get_diet_recommendations(
        NEW_USER_PROFILE, NEW_USER_CONTEXT, top_n=3
    )
    _print_meals(new_meals)

    print("\n[Exercises]")
    new_exercises = get_exercise_recommendations(
        NEW_USER_PROFILE, NEW_USER_CONTEXT, top_n=3
    )
    _print_exercises(new_exercises)

    # ── Experienced user (challenging context) ─────────────────────────────────
    _divider("👤 EXPERIENCED USER  (poor sleep + high glucose + high burnout)")

    print("\n[Meals — Breakfast]")
    exp_meals = get_diet_recommendations(
        EXPERIENCED_USER_PROFILE, EXPERIENCED_USER_CONTEXT, top_n=3
    )
    _print_meals(exp_meals)

    print("\n[Exercises]")
    exp_exercises = get_exercise_recommendations(
        EXPERIENCED_USER_PROFILE, EXPERIENCED_USER_CONTEXT, top_n=3
    )
    _print_exercises(exp_exercises)

    # ── Sanity checks ──────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("✅ Sanity checks:")

    ok = True

    if len(new_meals) >= 1:
        print("  [PASS] New user received meal recommendations (cold start works)")
    else:
        print("  [FAIL] New user got no meal recommendations!")
        ok = False

    if len(new_exercises) >= 1:
        print("  [PASS] New user received exercise recommendations")
    else:
        print("  [FAIL] New user got no exercise recommendations!")
        ok = False

    # Burnout filter: HIIT / strength must not appear for experienced user
    hiit_in_exp = [
        e for e in exp_exercises
        if e["exercise_type"].lower() in ("hiit", "strength")
    ]
    if not hiit_in_exp:
        print("  [PASS] Burnout filter working — no HIIT/strength for high-burnout user")
    else:
        print(f"  [FAIL] Burnout filter failed — found: {[e['name'] for e in hiit_in_exp]}")
        ok = False

    if ok:
        print("\n🎉 Phase 1 complete! All checks passed.")
    else:
        print("\n⚠  Some checks failed. Review output above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
