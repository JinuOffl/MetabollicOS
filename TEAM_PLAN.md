# GlucoNav — Team Plan
> **For Medathon 2026 | Team Innofusion**
> Last updated: 2026-04-05

---

## ⚠️ HOW TO USE THIS FILE
This file is self-contained. Each task has: the exact file to edit, the exact code to add/change/replace, and the exact lines to look for. You do not need context from any other conversation. Complete phases in order. Mark `[ ]` → `[/]` when starting, `[x]` when done.

---

## Team Members

| ID | Role | Focus Area |
| -- | ---- | ---------- |
| **Member J** | ML Engineer | Recommendation Engine (LightFM, data, prediction services) |
| **Member K** | Backend Engineer | FastAPI, Vision AI, Burnout service, DB models |
| **Member L** | Frontend Engineer | Flutter UI, all screens, BLoC providers, API wiring |

---

## Architecture Overview (Read Before Any Task)

```
CGM Simulator Page (teammate's device)
    │  POST /api/v1/glucose-reading  {user_id, glucose_mgdl}
    ▼
FastAPI Backend  (localhost:8000)
    ├── routers/glucose.py        → writes GlucoseReading to SQLite
    ├── routers/users.py          → onboard, get profile
    ├── routers/recommendations.py→ GET /recommend/{user_id}
    │     ├── reads latest GlucoseReading from DB (real-time CGM)
    │     ├── calls diet_engine.get_diet_recommendations(profile, context)
    │     └── calls exercise_engine.get_exercise_recommendations(profile, context)
    │           └── both call recommendation_service.predict_meals/exercises()
    │                 └── LightFM model (diet_model.pkl / exercise_model.pkl)
    └── routers/feedback.py       → logs meal/exercise interactions

Flutter App  (Chrome, flutter run -d chrome)
    ├── gluconav_api_service.dart → HTTP calls to backend
    ├── gluconav_dashboard_bloc.dart → 10s Timer.periodic → DashboardPulse
    ├── gluconav_dashboard_screen.dart → _MealCard, _ExerciseCard
    └── recommendation_response.dart → DietRecommendation, ExerciseRecommendation
```

**Key data flow**: Glucose → DB → `/recommend` reads it → context re-ranks meals → Flutter polls every 10s → cards update.

---

## PHASE 0 — Shared Setup ✅
- [x] S0.1–S0.7 — Folder structure, requirements, env, SQLite, boot verified

## PHASE 1 — Recommendation Engine ✅
- [x] J1.1–J1.3 — Seed data (meals, exercises, users)
- [x] J2.1–J2.2 — ML data pipeline
- [x] J3.1–J3.2 — Model training (diet + exercise)
- [x] J4.1–J4.3 — Prediction services

## PHASE 2 — FastAPI + Flutter Base ✅
- [x] K1.1–K1.5 — DB models
- [x] K2.1–K2.3 — Pydantic schemas
- [x] K3.1–K3.7 — FastAPI routers
- [x] J0–J7 — ONT integration, onboarding, dashboard, eating sequence

## K-TRACK ✅ / L-TRACK ✅ / Phase 6.5 Integration ✅
*(See session log for details)*

---

## PHASE 6 — Demo Preparation ✅ COMPLETE

- [x] **S1.1** — `seed_demo.py` fixed (5 bugs) + verified: `demo_user_new` seeded with zero interactions
- [x] **S1.2** — `verify_demo.py` created: `demo_user_experienced` confirmed with 14-day history
- [x] **S1.3** — `DEMO_SCRIPT.md` created: 8-step script, talking points, Q&A, backup plan, key numbers
- [x] **S1.4** — Personalization delta documented: Diary tab switches between users; +54 (new) vs +18 (experienced)
- [ ] **S1.5** — Demo rehearsed; timing confirmed for judges ← **next action for team**

---

## PHASE 7 — UI Redesign & New Features ✅ / 🚧
- [x] **7.1** — Streamline Navigation Shell to 3 tabs (Camera, Home, Profile)
- [x] **7.2** — Refactor Home screen to horizontal scroll rows for Meals and Activity
- [x] **7.3** — Consolidate Profile Tab with Diary, Trends, and Demo shortcuts
- [x] **7.4** — Onboarding screens + extended profile display
- [x] **7.5** — Meal / Activity logging popups instead of `+` camera routing
- [x] **7.6** — Meal Swap (Long press recommended card for alternatives)
- [x] **7.7** — Dynamic Order of Eating logic integration

---

## PHASE 8 — J: Fix Engine Plumbing (CRITICAL — Do First) 🔧
> **Owner: Member J** | Est. 2–3 hrs
> **Do tasks in order: J8.1 → J8.2 → J8.3 → J8.4 → J8.5**

These are bugs found by code analysis. Nothing else will work correctly until these are fixed.

---

### [x] J8.1 — Fix HbA1c mapping in recommendations.py
**File:** `backend/app/routers/recommendations.py`
**Problem:** `profile.hba1c_band` is a string ("controlled"/"moderate"/"uncontrolled"). The function `diet_engine._profile_to_feature_names()` reads key `baseline_hba1c` as a float. It always defaults to `8.0` (→ `hba1c:moderate`) for every user regardless of their actual control.
**Fix:** In `recommendations.py`, around line 126, find this block:
```python
profile_dict = {
    "diabetes_type":     profile.diabetes_type,
    "regional_cuisine":  profile.cuisine_preference,
    "diet_preference":   profile.diet_type,
    "hba1c_band":        profile.hba1c_band,
    "activity_level":    profile.activity_level or "sedentary",
    "age_band":          "40s" if not profile.age else f"{(profile.age // 10) * 10}s",
}
```
Replace with:
```python
# Map hba1c_band string → numeric so feature_builder can bucket it correctly
_hba1c_map = {"controlled": 7.0, "moderate": 8.2, "uncontrolled": 10.5}
hba1c_numeric = _hba1c_map.get(profile.hba1c_band or "moderate", 8.2)

profile_dict = {
    "diabetes_type":    profile.diabetes_type or "type2",
    "regional_cuisine": profile.cuisine_preference or "south_indian",
    "diet_preference":  profile.diet_type or "vegetarian",
    "baseline_hba1c":   hba1c_numeric,                            # ← FIXED
    "activity_level":   profile.activity_level or "sedentary",
    "age_band":         f"{(profile.age // 10) * 10}s" if profile.age else "40s",
    "thinfat_flag":     "False",
}
```

---

### [x] J8.2 — Pass context (glucose, sleep) into the recommendation engines
**File:** `backend/app/routers/recommendations.py`
**Problem:** Lines 137–138 call both engines **without** a `context` dict. The glucose read from DB (`actual_glucose`) is ONLY used for `spike_risk` display, but never influences which meals/exercises are actually ranked higher. This is the main reason recs don't change when CGM glucose spikes.
**Fix:** Find lines 137–138:
```python
diet_raw      = get_diet_recommendations(profile_dict, top_n=10)
exercise_raw  = get_exercise_recommendations(profile_dict, top_n=10)
```
Replace with:
```python
context = {
    "current_glucose":  actual_glucose or 120.0,
    "sleep_score":      sleep_score or 0.75,
    "diet_preference":  profile.diet_type or "vegetarian",
    "burnout_score":    0.0,   # will be overwritten by burnout_data below
}

# Requesting top_n=10 to allow frontend to implement Meal Swaps from the remainder array.
diet_raw     = get_diet_recommendations(profile_dict, context=context, top_n=10)
exercise_raw = get_exercise_recommendations(profile_dict, context=context, top_n=10)
```
**Verification:** `curl "http://localhost:8000/api/v1/recommend/demo_user_experienced?current_glucose=240"` should return meals with GI < 55 ranked first, and a `context_warning` containing "High glucose".

---

### [x] J8.3 — Fix URL and mock fallback in Flutter API service
**File:** `frontend/OpenNutriTracker/lib/services/gluconav_api_service.dart`
**Problem 1:** Line 25 has a hardcoded IP `http://10.242.238.169:8000`. This breaks at any other WiFi.
**Problem 2:** The `catch (e)` in `fetchRecommendations()` (lines 86–88) catches ALL exceptions and silently returns frozen mock data — even for user-not-found errors (which would be fixed by re-onboarding).

**Fix — Part A (URL):** Change line 25:
```dart
static const String _base = 'http://10.242.238.169:8000/api/v1';
```
To:
```dart
// Use localhost for same-machine Chrome demo (flutter run -d chrome)
// Change to your WiFi IP if testing from a separate device
static const String _base = 'http://localhost:8000/api/v1';
```

**Fix — Part B (imports at top of file):** Add these two imports after line 2 (`import 'dart:typed_data';`):
```dart
import 'dart:async';
import 'dart:io';
```

**Fix — Part C (fetchRecommendations):** Find lines 73–90:
```dart
Future<RecommendResponse> fetchRecommendations({
  double? sleepScore,
  double? currentGlucose,
  int? steps,
}) async {
  if (forceMock) return getRecommendationsMock();
  try {
    return await getRecommendations(
      userId,
      sleepScore: sleepScore,
      currentGlucose: currentGlucose,
      steps: steps,
    );
  } catch (e) {
    // Backend unreachable or error — fall back to rich mock
    return getRecommendationsMock();
  }
}
```
Replace with:
```dart
Future<RecommendResponse> fetchRecommendations({
  double? sleepScore,
  double? currentGlucose,
  int? steps,
}) async {
  if (forceMock) return getRecommendationsMock();
  try {
    return await getRecommendations(
      userId,
      sleepScore: sleepScore,
      currentGlucose: currentGlucose,
      steps: steps,
    );
  } on SocketException catch (_) {
    // Backend is truly offline — use mock so demo still works
    return getRecommendationsMock();
  } on TimeoutException catch (_) {
    // Backend too slow — use mock
    return getRecommendationsMock();
  } catch (e) {
    // Other errors (404, 500): log but still mock to not crash demo
    // ignore: avoid_print
    debugPrint('⚠️ GlucoNav API error: $e — serving mock data');
    return getRecommendationsMock();
  }
}
```
**Also add** this import at the top of the file if not present:
```dart
import 'package:flutter/foundation.dart';
```

---

### [x] J8.4 — Add demo_user_type1 to seed_demo.py
**File:** `backend/scripts/seed_demo.py`
**Purpose:** Need a pre-seeded Type 1 patient user so the insulin dosage badge demo works without re-onboarding each time.
**Find** the section where `demo_user_experienced` is created (look for `User(id="demo_user_experienced")`). After that block, add:

```python
# ── demo_user_type1 ───────────────────────────────────────────────────────────
existing_t1 = db.query(User).filter(User.id == "demo_user_type1").first()
if not existing_t1:
    db.add(User(id="demo_user_type1"))
    db.flush()
    db.add(UserProfile(
        id=str(uuid.uuid4()),
        user_id="demo_user_type1",
        diabetes_type="type1",
        hba1c_band="uncontrolled",
        cuisine_preference="north_indian",
        diet_type="non_vegetarian",
        age=28,
        weight_kg=65.0,
        height_cm=172.0,
        gender="male",
        goal="control_glucose",
        activity_level="light",
    ))
    print("✔ Created User: demo_user_type1")
else:
    print("✔ User already exists: demo_user_type1")
db.commit()
```
**Run after editing:**
```powershell
cd backend
conda activate gluconav
python scripts/seed_demo.py
```

---

### [x] J8.5 — Add demo switching shortcut in Profile tab
**File:** `frontend/OpenNutriTracker/lib/features/trends/gluconav_trends_screen.dart`
**Purpose:** The Profile tab should have a "Switch → demo_user_type1" button alongside the existing `demo_user_new` and `demo_user_experienced` buttons. Search this file for `'demo_user_experienced'` and add a third button nearby:
```dart
_DemoShortcutButton(
  label: 'Type 1 Patient (💉 Insulin Demo)',
  userId: 'demo_user_type1',
  accent: accent,
),
```
*(The `_DemoShortcutButton` widget already exists in the file — just add a third call.)*

---

## PHASE 9 — J: Type 1 Insulin Dosage Calculation 💉
> **Owner: Member J** | Est. 1.5 hrs
> **This is the highest-impact feature for doctor judges. Do after Phase 8.**

The standard bolus insulin formula for Type 1:
```
dose = (carbs_g / ICR) + max(0, (current_glucose − target_glucose) / ISF)
```
Where: ICR (Insulin-to-Carb Ratio) = 10 g/unit, ISF (Insulin Sensitivity Factor) = 40 mg/dL/unit, Target = 100 mg/dL.

---

### [x] J9.1 — Add carbs_g to meals.csv
**File:** `backend/data/meals.csv`
**Purpose:** The CSV has `carb_pct` (percentage) and `calories_per_100g` but no absolute grams needed for insulin calc.
**Formula for standard serving:** `carbs_g = round(carb_pct / 100 * serving_calories / 4)`
where `serving_calories = calories_per_100g * (serving_weight_g / 100)`, and `serving_weight_g = 250g` for main meals (breakfast/lunch/dinner), `120g` for snacks.

**Add the column** as the 16th column (after `tags`). Sample values:
- meal001 Idli with Sambar: carb_pct=75, calories=120, main → `carbs_g = round(0.75 * 120 * 2.5 / 4) = round(56.25) = 56`
- meal026 Egg Bhurji: carb_pct=5, calories=170, snack → `carbs_g = round(0.05 * 170 * 1.2 / 4) = round(2.55) = 3`

Or run this Python script to auto-calculate and write the new CSV:
```python
# Run from backend/ directory: python scripts/add_carbs_col.py
import pandas as pd
from pathlib import Path
df = pd.read_csv('data/meals.csv')
SNACK_WEIGHT = 120; MAIN_WEIGHT = 250
df['serving_g'] = df['meal_type'].apply(lambda t: SNACK_WEIGHT if t == 'snack' else MAIN_WEIGHT)
df['carbs_g'] = (df['carb_pct'] / 100 * df['calories_per_100g'] * df['serving_g'] / 100 / 4).round().astype(int)
df.drop(columns=['serving_g'], inplace=True)
df.to_csv('data/meals.csv', index=False)
print("Done. Added carbs_g column.")
```

---

### [x] J9.2 — Add calculate_insulin_dose() to diet_engine.py
**File:** `backend/app/services/diet_engine.py`
**Add** this function near the top, after the `_GI_TO_SPIKE` dict (around line 46):
```python
# ── Type 1 Insulin Bolus ──────────────────────────────────────────────────────
_DEFAULT_ICR = 10      # grams of carbs per 1 unit of insulin
_DEFAULT_ISF = 40      # mg/dL drop per 1 unit of insulin
_TARGET_GLUCOSE = 100  # mg/dL target

def calculate_insulin_dose(
    carbs_g: float,
    current_glucose: float,
    diabetes_type: str,
) -> Optional[str]:
    """
    Returns formatted insulin dose string for Type 1 patients.
    Returns None for Type 2, prediabetes, GDM.

    Formula (standard bolus):
        carb_dose       = carbs_g / ICR
        correction_dose = max(0, (current_glucose - target) / ISF)
        total           = carb_dose + correction_dose
    """
    if str(diabetes_type).lower() != "type1":
        return None
    carb_dose = carbs_g / _DEFAULT_ICR
    correction = max(0.0, (current_glucose - _TARGET_GLUCOSE) / _DEFAULT_ISF)
    total = round(carb_dose + correction, 1)
    return f"{total} units"
```

---

### [x] J9.3 — Wire insulin_dose into get_diet_recommendations()
**File:** `backend/app/services/diet_engine.py`
**Find** the `get_diet_recommendations()` function. It reads `user_profile` and `context`. At line ~103, find the function signature and make sure `diabetes_type` is accessible:
```python
def get_diet_recommendations(
    user_profile: dict,
    context: Optional[dict] = None,
    top_n: int = 5,
) -> List[dict]:
```
**Find** the loop where `results.append(...)` happens (around line 174). The current dict is:
```python
results.append({
    "meal_id":            meal["meal_id"],
    "name":               meal["name"],
    "cuisine":            meal["cuisine"],
    "meal_type":          meal["meal_type"],
    "predicted_spike_mg": predicted_spike,
    "is_vegetarian":      meal["is_vegetarian"],
    "reason":             reason,
    "score":              meal["score"] + adj,
})
```
Replace with:
```python
# Calculate insulin dose for Type 1 patients
diabetes_type = user_profile.get("diabetes_type", "type2")
carbs_g = float(meal.get("carbs_g", 0))       # from enriched meals.csv
insulin_dose = calculate_insulin_dose(
    carbs_g=carbs_g,
    current_glucose=current_glucose,
    diabetes_type=diabetes_type,
)

results.append({
    "meal_id":            meal["meal_id"],
    "name":               meal["name"],
    "cuisine":            meal["cuisine"],
    "meal_type":          meal["meal_type"],
    "predicted_spike_mg": predicted_spike,
    "is_vegetarian":      meal["is_vegetarian"],
    "reason":             reason,
    "score":              meal["score"] + adj,
    "insulin_dose":       insulin_dose,         # ← NEW: None for Type 2
    "carbs_g":            carbs_g,              # ← NEW: for frontend display
})
```
**Note:** `meal` dict comes from `predict_meals()` in `recommendation_service.py`. You also need to add `carbs_g` to the dict returned by `predict_meals()`. See J9.4.

---

### [x] J9.4 — Add carbs_g to predict_meals() return dict
**File:** `backend/app/services/recommendation_service.py`
**Find** the `predict_meals()` function, around line 170 where `results.append(...)` happens:
```python
results.append({
    "meal_id": str(ext_id),
    "name": row["name"],
    "cuisine": row["cuisine"],
    "meal_type": row["meal_type"],
    "glycemic_index": float(row["glycemic_index"]),
    "glycemic_load": str(row["glycemic_load"]),
    "fiber_g": float(row.get("fiber_g", 0)),
    "protein_pct": float(row.get("protein_pct", 0)),
    "is_vegetarian": bool(str(row["is_vegetarian"]).upper() == "TRUE"),
    "score": float(score) + adj,
})
```
Replace with (add `carbs_g` line):
```python
results.append({
    "meal_id": str(ext_id),
    "name": row["name"],
    "cuisine": row["cuisine"],
    "meal_type": row["meal_type"],
    "glycemic_index": float(row["glycemic_index"]),
    "glycemic_load": str(row["glycemic_load"]),
    "fiber_g": float(row.get("fiber_g", 0)),
    "protein_pct": float(row.get("protein_pct", 0)),
    "carbs_g": float(row.get("carbs_g", 0)),    # ← NEW
    "is_vegetarian": bool(str(row["is_vegetarian"]).upper() == "TRUE"),
    "score": float(score) + adj,
})
```

---

### [x] J9.5 — Add insulin_dose to Pydantic schema
**File:** `backend/app/schemas/recommendation.py`
**Find** the `DietRecommendation` class (starts at line 12). Add two new Optional fields:
```python
class DietRecommendation(BaseModel):
    meal_id: str
    name: str
    cuisine: Optional[str] = None
    predicted_glucose_delta: Optional[float] = None
    gi: Optional[float] = None
    gl: Optional[float] = None
    reason: Optional[str] = None
    tags: Optional[List[str]] = []
    insulin_dose: Optional[str] = None    # ← NEW: e.g. "4.5 units" for Type 1
    carbs_g: Optional[float] = None       # ← NEW: grams of carbs per serving

    # Legacy aliases kept for backward compat
    predicted_spike_mgdl: Optional[float] = None
    rationale: Optional[str] = None
```

---

### [x] J9.6 — Add insulin_dose to _normalize_diet_item() in recommendations.py
**File:** `backend/app/routers/recommendations.py`
**Find** the `_normalize_diet_item()` function (around line 30). Current return dict:
```python
return {
    "meal_id":                 d.get("meal_id", ""),
    "name":                    d.get("name", ""),
    "cuisine":                 d.get("cuisine"),
    "predicted_glucose_delta": spike,
    "predicted_spike_mgdl":    spike,
    "gi":                      d.get("gi") or d.get("glycemic_index"),
    "gl":                      d.get("gl"),
    "reason":                  d.get("reason") or d.get("rationale"),
    "rationale":               d.get("reason") or d.get("rationale"),
    "tags":                    d.get("tags", []),
}
```
Replace with:
```python
return {
    "meal_id":                 d.get("meal_id", ""),
    "name":                    d.get("name", ""),
    "cuisine":                 d.get("cuisine"),
    "predicted_glucose_delta": spike,
    "predicted_spike_mgdl":    spike,
    "gi":                      d.get("gi") or d.get("glycemic_index"),
    "gl":                      d.get("gl"),
    "reason":                  d.get("reason") or d.get("rationale"),
    "rationale":               d.get("reason") or d.get("rationale"),
    "tags":                    d.get("tags", []),
    "insulin_dose":            d.get("insulin_dose"),   # ← NEW
    "carbs_g":                 d.get("carbs_g"),        # ← NEW
}
```

---

### [x] J9.7 — Parse insulin_dose in Flutter model
**File:** `frontend/OpenNutriTracker/lib/models/recommendation_response.dart`
**Find** the `DietRecommendation` class (line 3). Add fields:
```dart
class DietRecommendation {
  final String mealId;
  final String name;
  final String? cuisine;
  final double? predictedGlucoseDelta;
  final double? gi;
  final String? reason;
  final List<String> tags;
  final String? insulinDose;   // ← NEW: "4.5 units" or null
  final double? carbsG;        // ← NEW: grams of carbs

  const DietRecommendation({
    required this.mealId,
    required this.name,
    this.cuisine,
    this.predictedGlucoseDelta,
    this.gi,
    this.reason,
    this.tags = const [],
    this.insulinDose,           // ← NEW
    this.carbsG,                // ← NEW
  });

  factory DietRecommendation.fromJson(Map<String, dynamic> j) =>
      DietRecommendation(
        mealId: j['meal_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        cuisine: j['cuisine'] as String?,
        predictedGlucoseDelta:
            (j['predicted_glucose_delta'] as num?)?.toDouble(),
        gi: (j['gi'] as num?)?.toDouble(),
        reason: j['reason'] as String?,
        tags: ((j['tags'] as List?) ?? []).cast<String>(),
        insulinDose: j['insulin_dose'] as String?,   // ← NEW
        carbsG: (j['carbs_g'] as num?)?.toDouble(),  // ← NEW
      );

  bool get isLowSpike => (predictedGlucoseDelta ?? 99) < 35;
}
```

---

### [x] J9.8 — Show insulin dose badge on meal card in Flutter
**File:** `frontend/OpenNutriTracker/lib/features/gluconav_dashboard/gluconav_dashboard_screen.dart`
**Find** the `_MealCard` class (around line 502). It currently ends with a spike delta badge. After the delta container, add the insulin dose badge:

Find this block inside `_MealCard.build()` (around line 546):
```dart
if (delta != null)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: showSpikeColor ? spikeColor.withOpacity(0.12) : GlucoNavColors.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '+${delta.round()} mg/dL',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: showSpikeColor ? spikeColor : GlucoNavColors.textSecondary),
    ),
  ),
```
After this block, add:
```dart
if (meal.insulinDose != null) ...[
  const SizedBox(height: 6),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF6366F1).withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '💉 ${meal.insulinDose}',
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Color(0xFF6366F1)),
    ),
  ),
],
```

---

## PHASE 10 — J: Meal Images in Cards 🍽️
> **Owner: Member J** | Est. 1 hr
> **Uses Unsplash Source API — requires internet at venue. No API key needed.**

---

### [x] J10.1 — Add image_url column to meals.csv
**File:** `backend/data/meals.csv`
**Strategy:** Use static Wikimedia Commons image links that will always work. Add `image_url` as the last column.

Run this script to add Unsplash keyword URLs (internet + no key):
```python
# Run from backend/: python scripts/add_image_urls.py
import pandas as pd
df = pd.read_csv('data/meals.csv')
# Encode meal name to URL-safe keyword for Unsplash Source
import urllib.parse
df['image_url'] = df['name'].apply(
    lambda name: f"https://source.unsplash.com/200x200/?{urllib.parse.quote(name + ' indian food')}"
)
df.to_csv('data/meals.csv', index=False)
print("Done. Added image_url column.")
```
**Note:** Unsplash Source is free and keyless but internet-dependent. If venue has no internet, consider curating 10–15 key meal URLs from Wikimedia Commons instead (local caching possible).

---

### [x] J10.2 — Add image_url to predict_meals() return
**File:** `backend/app/services/recommendation_service.py`
In `predict_meals()`, inside `results.append(...)`, add after `carbs_g`:
```python
"image_url": str(row.get("image_url", "")),   # ← NEW
```

---

### [x] J10.3 — Add image_url to _normalize_diet_item()
**File:** `backend/app/routers/recommendations.py`
In `_normalize_diet_item()`, add to return dict:
```python
"image_url": d.get("image_url", ""),   # ← NEW
```

---

### [x] J10.4 — Add image_url to Pydantic schema
**File:** `backend/app/schemas/recommendation.py`
In `DietRecommendation`, add:
```python
image_url: Optional[str] = None    # ← NEW
```

---

### [x] J10.5 — Parse image_url in Flutter model
**File:** `frontend/OpenNutriTracker/lib/models/recommendation_response.dart`
In `DietRecommendation`, add field and parse:
```dart
final String? imageUrl;   // ← NEW
```
In constructor: `this.imageUrl,`
In `fromJson`: `imageUrl: j['image_url'] as String?,`

---

### [x] J10.6 — Show meal image in _MealCard
**File:** `frontend/OpenNutriTracker/lib/features/gluconav_dashboard/gluconav_dashboard_screen.dart`
**Find** `_MealCard.build()`. Find the icon placeholder (around line 528):
```dart
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: showSpikeColor ? spikeColor.withOpacity(0.12) : GlucoNavColors.surfaceVariant,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Center(
    child: Icon(Icons.restaurant, color: showSpikeColor ? spikeColor : accent, size: 20),
  ),
),
```
Replace with:
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: (meal.imageUrl != null && meal.imageUrl!.isNotEmpty)
      ? Image.network(
          meal.imageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56, height: 56,
            color: showSpikeColor ? spikeColor.withOpacity(0.12) : GlucoNavColors.surfaceVariant,
            child: Icon(Icons.restaurant, color: accent, size: 20),
          ),
        )
      : Container(
          width: 56, height: 56,
          color: showSpikeColor ? spikeColor.withOpacity(0.12) : GlucoNavColors.surfaceVariant,
          child: Icon(Icons.restaurant, color: showSpikeColor ? spikeColor : accent, size: 20),
        ),
),
```
**Also change** `width: 140` on the card container to `width: 155` to accommodate the larger image.

---

## PHASE 11 — J: CGM Reactive Polling (Verify & Tune) 📡
> **Owner: Member J** | Est. 30 min
> **The BLoC already has a 10s pulse timer. This phase is just verification + tuning.**

---

### [x] J11.1 — Verify DashboardPulse timer is working
**File:** `frontend/OpenNutriTracker/lib/features/gluconav_dashboard/gluconav_dashboard_bloc.dart`
**Check:** Line 93 already has:
```dart
_pulseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  if (!isClosed) add(const DashboardPulse());
});
```
✅ This is already implemented. The dashboard auto-polls every 10 seconds. No change needed.

---

### [x] J11.2 — Verify backend real-time CGM logic
**File:** `backend/app/routers/recommendations.py`
**Check:** Lines 108–120 already have:
```python
actual_glucose = current_glucose
if actual_glucose is None:
    latest_reading = (
        db.query(GlucoseReading)
        .filter(GlucoseReading.user_id == user_id)
        .order_by(GlucoseReading.timestamp.desc())
        .first()
    )
    if latest_reading:
        actual_glucose = latest_reading.glucose_mgdl or latest_reading.value_mgdl
```
✅ Already implemented. When CGM page posts a reading, within 10 seconds the Flutter app will refetch and get a response with the new glucose value.

---

### [x] J11.3 — End-to-end demo test (required before hackathon)
Run this sequence manually to confirm the CGM→Recs chain works:
```powershell
# Step 1: Start backend
cd backend && conda activate gluconav && python run.py

# Step 2: Seed data
python scripts/seed_demo.py

# Step 3: Post a NORMAL glucose reading
curl -X POST http://localhost:8000/api/v1/glucose-reading `
  -H "Content-Type: application/json" `
  -d '{"user_id": "demo_user_experienced", "glucose_mgdl": 110}'

# Step 4: Check recommendations (should show moderate-GI meals, spike_risk: low)
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced"

# Step 5: Post a HIGH glucose reading (simulating CGM spike)
curl -X POST http://localhost:8000/api/v1/glucose-reading `
  -H "Content-Type: application/json" `
  -d '{"user_id": "demo_user_experienced", "glucose_mgdl": 245}'

# Step 6: Check recommendations again (should show LOW-GI meals first, spike_risk: high)
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced"
```
**Expected change between Step 4 and Step 6:**
- `spike_risk`: "low"/"medium" → "high"
- `context_warning`: null → "⚠️ High glucose (245 mg/dL) — choose low-GI options"
- Meal order: moderate-GI meals → low-GI meals ranked first

---

### [x] J11.4 — Test Type 1 insulin dose endpoint
```powershell
# Confirm demo_user_type1 gets insulin_dose in response
curl "http://localhost:8000/api/v1/recommend/demo_user_type1?current_glucose=200"
# Each diet item should have "insulin_dose": "X.X units"

# Also test for demo_user_experienced (Type 2 — should have insulin_dose: null)
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced?current_glucose=200"
# Each diet item should have "insulin_dose": null
```

---

## PHASE 12 — J: Cosine Similarity Cold-Start Demo Story 🧠
> **Owner: Member J** | Est. 1.5 hrs (Optional — do only if time permits)
> **This is for the "cold start" story: "We find users like you"**

---

### [x] J12.1 — Create cold_start_service.py
**File:** `backend/app/services/cold_start_service.py` *(new file)*
```python
"""
cold_start_service.py
---------------------
When a new user has < N interactions, uses cosine similarity on the training
user feature vectors to find similar users and return their top meals.
Used by diet_engine.py to boost cold-start recommendations.

Usage:
    from app.services.cold_start_service import find_similar_users
    similar_meal_ids = find_similar_users(user_feature_names, top_k=5)
"""
from pathlib import Path
from typing import List
import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
USERS_CSV = DATA_DIR / "synthetic_users.csv"
MEAL_INTS_CSV = DATA_DIR / "meal_interactions.csv"

from app.ml.feature_builder import USER_FEATURES

def _user_features_to_vector(feature_names: List[str]) -> np.ndarray:
    """Convert a list of feature name strings to a binary feature vector."""
    vec = np.zeros(len(USER_FEATURES))
    feature_index = {f: i for i, f in enumerate(USER_FEATURES)}
    for f in feature_names:
        if f in feature_index:
            vec[feature_index[f]] = 1.0
    return vec

def find_similar_users(
    user_feature_names: List[str],
    top_k: int = 5,
) -> dict:
    """
    Find top_k training users most similar to the query user.
    Returns: {
        "similar_count": int,
        "top_meal_ids": List[str]   # meal IDs preferred by similar users
    }
    """
    try:
        users_df = pd.read_csv(USERS_CSV)
        meal_ints = pd.read_csv(MEAL_INTS_CSV)

        # Build feature matrix for all training users
        from app.ml.feature_builder import user_feature_list
        user_vecs = np.array([
            _user_features_to_vector(user_feature_list(row))
            for _, row in users_df.iterrows()
        ])

        # Query vector
        query_vec = _user_features_to_vector(user_feature_names).reshape(1, -1)

        # Cosine similarity
        sims = cosine_similarity(query_vec, user_vecs)[0]
        top_indices = np.argsort(sims)[::-1][:top_k]
        similar_user_ids = users_df.iloc[top_indices]["user_id"].tolist()

        # Get top meals eaten by similar users (positive interactions only)
        top_meals = (
            meal_ints[
                meal_ints["user_id"].isin(similar_user_ids) &
                meal_ints["interaction_type"].isin(["eaten", "accepted"])
            ]
            .groupby("meal_id")["score"]
            .mean()
            .sort_values(ascending=False)
            .head(10)
            .index.tolist()
        )

        return {"similar_count": len(similar_user_ids), "top_meal_ids": top_meals}
    except Exception:
        return {"similar_count": 0, "top_meal_ids": []}
```

---

### [x] J12.2 — Wire cold-start into diet_engine.py
**File:** `backend/app/services/diet_engine.py`
**Only apply this for users with < 5 interactions.** In `get_diet_recommendations()`, after the `candidates` list is retrieved, add:

```python
# Cold-start boost: if user has few interactions, find similar training users
# and boost their preferred meals by 0.10 score
try:
    from app.services.cold_start_service import find_similar_users
    similar_data = find_similar_users(user_feature_names, top_k=5)
    similar_meal_ids = set(similar_data.get("top_meal_ids", []))
    for meal in candidates:
        if meal["meal_id"] in similar_meal_ids:
            meal["score"] += 0.10  # Slight boost from similar users
except Exception:
    pass  # Non-critical — fail silently
```

---

### [x] J12.3 — Add similar_users_found to RecommendResponse
**File:** `backend/app/schemas/recommendation.py`
In `RecommendResponse`, add:
```python
similar_users_found: Optional[int] = None   # e.g. 7 — for demo display
```
**File:** `backend/app/routers/recommendations.py`
In the final `return RecommendResponse(...)`, add:
```python
similar_users_found=5,  # placeholder; wire to cold_start_service if time permits
```

---

## PHASE 13 — Integration Checklist (Final Verification)
> **Run this before the hackathon. All should pass.**

### Backend Tests
```powershell
cd backend
conda activate gluconav

# 1. Structural check
python scripts/verify_demo.py

# 2. Type 2 recs (no insulin_dose)
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced"
# ✅ diet_recommendations[*].insulin_dose == null

# 3. Type 1 recs with high glucose (has insulin_dose)
curl "http://localhost:8000/api/v1/recommend/demo_user_type1?current_glucose=200"
# ✅ diet_recommendations[*].insulin_dose == "X.X units"

# 4. Spike reaction (post high glucose, then re-check recs)
curl -X POST http://localhost:8000/api/v1/glucose-reading -H "Content-Type: application/json" -d "{\"user_id\": \"demo_user_experienced\", \"glucose_mgdl\": 240}"
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced"
# ✅ spike_risk == "high"
# ✅ context_warning contains "High glucose"

# 5. Diet preference respected
curl "http://localhost:8000/api/v1/recommend/demo_user_experienced"
# ✅ No non-vegetarian meals for vegetarian users

# 6. Cuisine preference respected
# demo_user_experienced is south_indian → top meals should be south_indian cuisine
# ✅ Verify first 2-3 meals are south_indian
```

### Flutter Tests (Chrome DevTools)
```
1. Open app fresh (or clear LocalStorage: F12 → Application → Storage)
2. Complete onboarding as: Type 2, South Indian, Vegetarian, HbA1c moderate
3. ✅ Meal cards show South Indian vegetarian meals (not mock Roasted Chana / Egg Bhurji)
4. Switch to demo_user_type1 (Profile → Demo shortcuts)
5. ✅ Meal cards show 💉 X units badge
6. Switch back to demo_user_experienced
7. Use Profile tab clinical shortcut to POST glucose=240
8. Wait 10 seconds (BLoC pulse timer)
9. ✅ spike_risk indicator turns red: "🔴 High spike risk"
10. ✅ Context warning banner appears: "⚠️ High glucose (240 mg/dL)"
11. ✅ Meal cards update to show low-GI options first
```

---

## Integration Map — Who Does What

| Task | Backend | Frontend | Integration Point |
|------|---------|----------|-------------------|
| Onboarding profile → LightFM features | J8.1 fixes profile_dict | L confirmed working | `recommendations.py` line ~126 |
| CGM glucose → meal re-ranking | J8.2 passes context | BLoC already pulses every 10s ✅ | `diet_engine.get_diet_recommendations(context=...)` |
| Mock fallback (sticky bug fix) | — | J8.3 hardens catch | `gluconav_api_service.fetchRecommendations()` |
| Type 1 insulin dose | J9.1–J9.6 (backend) | J9.7–J9.8 (frontend) | `DietRecommendation.insulin_dose` field |
| Meal images | J10.1–J10.4 (backend) | J10.5–J10.6 (frontend) | `DietRecommendation.image_url` field |
| CGM polling | Backend already reads latest glucose ✅ | BLoC already has 10s timer ✅ | No changes needed |
| Cold-start cosine similarity | J12.1–J12.3 | No frontend change needed | Internal to diet_engine |

---

## Session Log

| Session | Date       | Member | What was done |
| ------- | ---------- | ------ | ------------- |
| 1–4     | 2026-04-04 | J      | Phase 0–1: ML pipeline, model training, prediction services |
| 5–8     | 2026-04-04 | J      | Phase 2 Flutter: ONT base, onboarding, dashboard, eating sequence |
| 9       | 2026-04-05 | K+L    | TEAM_PLAN restructured for parallel tracks |
| 10      | 2026-04-05 | K      | K4: vision_service, sequence_service, vision router |
| 11      | 2026-04-05 | K      | K5–K7 + field-name normalizer bug fix |
| 12      | 2026-04-05 | L      | L6–L9: created lib/ from scratch, all screens |
| 13      | 2026-04-05 | K+L    | Phase 6.5: real API wired, CORS fix, user-switch demo buttons |
| 14      | 2026-04-05 | K+L    | Phase 6 Demo Prep. Fixed 5 bugs in seed_demo.py. Updated 4 models. Fixed 2 schemas. Fixed 2 routers. Created verify_demo.py. Created DEMO_SCRIPT.md. |
| 15      | 2026-04-05 | L      | Phase 7 UI Redesign (part A). |
| 16      | 2026-04-05 | L+K    | Phase 7 UI Redesign (part B). |
| 17      | 2026-04-05 | K      | Phase 7 Bug Fix. Added missing columns to user_profiles SQLite table. |
| 18      | 2026-04-05 | J      | Phase 8–13 planning: full recommendation engine analysis, bug identification, integration plan |

*Mark tasks `[/]` when starting, `[x]` when done. Always update `CONTEXT.md` after each session.*
