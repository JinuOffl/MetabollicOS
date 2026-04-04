# GlucoNav — Team Plan
> **For Medathon 2026 | Team Innofusion**
> Last updated: 2026-04-04

---

## Team Members

| ID           | Role              | Focus Area                                                 |
| ------------ | ----------------- | ---------------------------------------------------------- |
| **Member J** | ML Engineer       | Recommendation Engine (LightFM, data, prediction services) |
| **Member K** | Backend Engineer  | FastAPI, Vision AI, Burnout service, DB models             |
| **Member L** | Frontend Engineer | Flutter UI, all screens, Riverpod providers, API wiring    |

---

## How to Use This File

1. When starting a task, mark it `[/]` (in progress)
2. When done, mark it `[x]` (complete)
3. After each task, update `CONTEXT.md` with what changed
4. Prefix: **J** = Member J | **K** = Member K | **L** = Member L | **S** = Shared

---

## PHASE 0 — Shared Setup (All three do this together first)

- [x] **S0.1** — Create full folder structure as per master prompt
- [x] **S0.2** — Create `backend/requirements.txt`
- [x] **S0.3** — Create `frontend/pubspec.yaml`
- [x] **S0.4** — Create `backend/.env` with placeholder values
- [x] **S0.5** — Initialize SQLite DB (SQLAlchemy `create_all`)
- [x] **S0.6** — Verify backend boots: `python run.py` → FastAPI at `localhost:8000`
- [x] **S0.7** — Verify frontend boots: `flutter run -d chrome`

---

## PHASE 1 — Recommendation Engine (Member J owns this phase)

### J1 — Seed Data
- [x] **J1.1** — `data/meals.csv` — 65 Indian meals (id, name, cuisine, meal_type, GI, GL, macros, prep_time, tags)
- [x] **J1.2** — `data/exercises.csv` — 30 exercises (id, name, type, duration, MET, glucose_benefit, burnout_cost, timing)
- [x] **J1.3** — `data/synthetic_users.csv` — 200 user profiles for model training

### J2 — ML Data Pipeline
- [x] **J2.1** — `ml/data_generator.py` — 200 synthetic users + realistic meal/exercise interactions
  - Low-GI meal → glucose_delta +10 to +30; High-GI → +40 to +90
  - Sleep penalty: if sleep_score < 0.5 → +20 to all deltas
  - HIIT when burnout > 7 → interaction_type = 'skipped'
- [x] **J2.2** — `ml/feature_builder.py` — Build LightFM sparse feature matrices for users, meals, exercises

### J3 — Model Training
- [x] **J3.1** — `ml/train_diet.py` — Train LightFM diet model (WARP loss, 32 components) → save `diet_model.pkl`
- [x] **J3.2** — `ml/train_exercise.py` — Train LightFM exercise model → save `exercise_model.pkl`

### J4 — Prediction Services
- [x] **J4.1** — `services/diet_engine.py` — `get_diet_recommendations()` with context adjustments (sleep penalty, glucose trend penalty)
- [x] **J4.2** — `services/exercise_engine.py` — `get_exercise_recommendations()` with burnout filter
- [x] **J4.3** — `services/recommendation_service.py` — LightFM wrapper (load model, dataset mapping, predict)

**✅ Phase 1 Done When:** `python backend/test_recommend.py` prints top-3 meals + exercises for a test user profile

---

## PHASE 2 — FastAPI Backend (Member K) + Flutter App (Member L)

### K1 — DB Models
- [ ] **K1.1** — `models/user.py` — User + UserProfile tables
- [ ] **K1.2** — `models/meal.py` — Meal + MealInteraction tables
- [ ] **K1.3** — `models/exercise.py` — Exercise + ExerciseInteraction tables
- [ ] **K1.4** — `models/glucose.py` — GlucoseReading table
- [ ] **K1.5** — `database.py` — SQLAlchemy session + engine setup

### K2 — Pydantic Schemas
- [ ] **K2.1** — `schemas/user.py` — OnboardRequest, UserResponse
- [ ] **K2.2** — `schemas/recommendation.py` — RecommendResponse (diet list + exercise list + context_warning + coach_mode)
- [ ] **K2.3** — `schemas/feedback.py` — FeedbackRequest, FeedbackResponse

### K3 — FastAPI Routers
- [ ] **K3.1** — `main.py` — FastAPI app with CORS middleware + router includes
- [ ] **K3.2** — `routers/users.py` — `POST /api/v1/users/onboard`
- [ ] **K3.3** — `routers/recommendations.py` — `GET /api/v1/recommend/{user_id}` (wires to J's engines)
- [ ] **K3.4** — `routers/feedback.py` — `POST /api/v1/feedback`
- [ ] **K3.5** — `routers/glucose.py` — `POST /api/v1/glucose-reading`
- [ ] **K3.6** — `routers/meals.py` — `GET /api/v1/meals`
- [ ] **K3.7** — `routers/exercises.py` — `GET /api/v1/exercises`

**✅ K-Phase 2 Done When:** Swagger UI at `localhost:8000/docs` shows all routes; `/recommend` returns valid JSON

---

### L1 — Flutter Foundation
- [ ] **L1.1** — `main.dart` — App entry with Riverpod `ProviderScope`
- [ ] **L1.2** — `router.dart` — `go_router` routes (onboarding, home, sequence, trends, activity)
- [ ] **L1.3** — Dart models: `user_profile.dart`, `meal_recommendation.dart`, `exercise_recommendation.dart`, `glucose_reading.dart`

### L2 — Services & Providers
- [ ] **L2.1** — `services/api_service.dart` — base HTTP client (base URL, headers, error handling)
- [ ] **L2.2** — `services/recommendation_service.dart` — `fetchRecommendations()`
- [ ] **L2.3** — `services/vision_service.dart` — `analyzeImage()` multipart POST
- [ ] **L2.4** — `providers/user_provider.dart` — user state + SharedPreferences
- [ ] **L2.5** — `providers/recommendation_provider.dart` — async recommendation state
- [ ] **L2.6** — `providers/glucose_provider.dart` — glucose readings state

### L3 — Onboarding Screen
- [ ] **L3.1** — `screens/onboarding/onboarding_screen.dart` — 5-step form (name/type, diet, cuisine, goal, HbA1c/activity)
- [ ] **L3.2** — `screens/onboarding/profile_setup_screen.dart` — POST to `/users/onboard`, save user_id

### L4 — Home Dashboard Screen
- [ ] **L4.1** — `screens/home/home_screen.dart` — sleep slider + meal type selector
- [ ] **L4.2** — Meal recommendation card widget (name, predicted spike badge, reason, "Log" button)
- [ ] **L4.3** — Exercise recommendation card widget (name, duration, glucose drop badge, "Done" button)
- [ ] **L4.4** — Context warning banner (e.g. "Poor sleep detected")

### L5 — Trends Screen
- [ ] **L5.1** — `screens/trends/trends_screen.dart` — 7-day glucose line chart (fl_chart)
- [ ] **L5.2** — Time-in-Range percentage (goal: >70% in 70–180 mg/dL)
- [ ] **L5.3** — Consistency streak counter
- [ ] **L5.4** — Last 5 meal interactions with outcome badges

**✅ L-Phase 2 Done When:** App shows real recommendations from K's backend; logging a meal works end-to-end

---

## PHASE 3 — Sequence Navigator (Member K — Vision backend; Member L — UI)

### K4 — Vision + LLM Backend
- [ ] **K4.1** — `services/vision_service.py` — ViT food detection (DrishtiSharma HuggingFace model)
- [ ] **K4.2** — `services/sequence_service.py` — Gemini 1.5 Flash eating sequence generation
- [ ] **K4.3** — `routers/vision.py` — `POST /api/v1/analyze-meal`

**✅ K4 Done When:** POST `/analyze-meal` with an image returns `detected_items` + `eating_sequence` JSON

### L6 — Sequence Navigator UI
- [ ] **L6.1** — `screens/sequence/camera_screen.dart` — image_picker (camera + gallery) → loading → POST
- [ ] **L6.2** — `screens/sequence/sequence_overlay_screen.dart` — meal photo + numbered badges
- [ ] **L6.3** — Numbered list (food name + reason per step)
- [ ] **L6.4** — Spike comparison cards ("Without: +67" vs "With: +24") + "Start eating!" button

**✅ Phase 3 Done When:** "Scan My Plate" → numbered overlay on photo with spike comparison stats

---

## PHASE 4 — Post-Meal Engine / Activity Snack (Member K + Member L)

### K5 — Spike Risk Service
- [ ] **K5.1** — `services/context_service.py` — `calculate_spike_risk()` (GI, sleep, steps, current glucose)

### L7 — Activity Snack UI
- [ ] **L7.1** — 20-min post-meal background timer after "Log this meal" tap
- [ ] **L7.2** — `screens/activity/activity_snack_screen.dart` — exercise card at 20-min mark
- [ ] **L7.3** — "Done!" → log `exercise_interaction` → update streak

---

## PHASE 5 — Burnout Shield (Member K + Member L)

### K6 — Burnout Backend
- [ ] **K6.1** — `services/burnout_service.py` — `calculate_burnout_score()` + `get_coach_mode()`
- [ ] **K6.2** — Include `coach_mode` in `/recommend` response payload

### L8 — Burnout Frontend
- [ ] **L8.1** — Read `coach_mode` from recommendation response
- [ ] **L8.2** — Supportive mode UI: softer language, no red warnings, encouraging emojis

---

## PHASE 6 — Demo Preparation (All three)

- [ ] **S1.1** — Seed `demo_user_new` (zero interaction history → generic recommendations)
- [ ] **S1.2** — Seed `demo_user_experienced` (14-day history → personalized recommendations)
- [ ] **S1.3** — Test 8-step demo script end-to-end
- [ ] **S1.4** — Side-by-side comparison: new vs experienced user recommendations

---

## Build Order

```
Phase 0 (Shared Setup — all three)
  ↓
Phase 1 (J: ML Engine — standalone, no API/Flutter needed)
  ↓
Phase 2 (K: FastAPI  +  L: Flutter — run in parallel, J supports integration)
  ↓
Phase 3 (K: Vision+LLM  +  L: Sequence UI — parallel)
  ↓
Phase 4 (K: Spike risk service  +  L: Post-meal timer UI)
  ↓
Phase 5 (K: Burnout backend  +  L: UI tone)
  ↓
Phase 6 (All: Demo prep)
```

---

## Session Log

| Session | Date       | Member | What was done                                                                                                                                                                                                            |
| ------- | ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1       | 2026-04-04 | J      | Phase 0: Shared setup complete. Folder structure, backend (FastAPI/SQLAlchemy) and frontend (Flutter) boilerplates created. SQLite initialized. Dependency installation verified (noting lightfm requires C++ compiler). |
| 2       | 2026-04-04 | J      | J1 complete: meals.csv (65 rows), exercises.csv (30 rows), synthetic_users.csv (200 rows) all verified. Seed data ready for J2.                                                                                          |
| 3       | 2026-04-04 | J      | J2 complete: data_generator.py (8112 meal + 3973 exercise interactions), feature_builder.py (23 user / 24 meal / 24 exercise features). exercises.csv re-saved with proper quoting.                                      |
| 4       | 2026-04-04 | J      | Phase 1 complete: J3 (Model Training) and J4 (Prediction Services) finished. Models trained with logistic loss and verified with test_recommend.py.                                                                      |

---

*Mark tasks `[/]` when starting, `[x]` when done. Always update `CONTEXT.md` after each session.*
