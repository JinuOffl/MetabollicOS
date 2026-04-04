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

## PHASE 2 — FastAPI Backend (Member K) + Flutter Integration (Member J)

### K1 — DB Models
- [x] **K1.1** — `models/user.py` — User + UserProfile tables
- [x] **K1.2** — `models/meal.py` — Meal + MealInteraction tables
- [x] **K1.3** — `models/exercise.py` — Exercise + ExerciseInteraction tables
- [x] **K1.4** — `models/glucose.py` — GlucoseReading table
- [x] **K1.5** — `database.py` — SQLAlchemy session + engine setup

### K2 — Pydantic Schemas
- [x] **K2.1** — `schemas/user.py` — OnboardRequest, UserResponse
- [x] **K2.2** — `schemas/recommendation.py` — RecommendResponse (diet list + exercise list + context_warning + coach_mode)
- [x] **K2.3** — `schemas/feedback.py` — FeedbackRequest, FeedbackResponse

### K3 — FastAPI Routers
- [x] **K3.1** — `main.py` — FastAPI app with CORS middleware + router includes
- [x] **K3.2** — `routers/users.py` — `POST /api/v1/users/onboard`
- [x] **K3.3** — `routers/recommendations.py` — `GET /api/v1/recommend/{user_id}` (wires to J's engines)
- [x] **K3.4** — `routers/feedback.py` — `POST /api/v1/feedback`
- [x] **K3.5** — `routers/glucose.py` — `POST /api/v1/glucose-reading`
- [x] **K3.6** — `routers/meals.py` — `GET /api/v1/meals`
- [x] **K3.7** — `routers/exercises.py` — `GET /api/v1/exercises`

**✅ K-Phase 2 Done When:** Swagger UI at `localhost:8000/docs` shows all routes; `/recommend` returns valid JSON

---

### J0 — Integrate OpenNutriTracker as Flutter Base
> **Strategy:** Use `frontend/OpenNutriTracker/` as the active Flutter project; add GlucoNav screens as new features inside ONT's feature-first structure. Keep BLoC (not Riverpod) to match ONT's existing architecture.

- [x] **J0.1** — Rename app: `pubspec.yaml` (`name: gluconav`), `main.dart` (class rename, title), app description
- [x] **J0.2** — Apply GlucoNav brand colors to `core/styles/color_schemes.dart` (`#0F6E56` primary teal, `#1D9E75` secondary)
- [x] **J0.3** — Add `shared_preferences: ^2.3.2` to `pubspec.yaml`; run `flutter pub get`
- [x] **J0.4** — Verify app boots with GlucoNav theme: `flutter run -d chrome`

### J5 — Diabetes Onboarding Extension
- [x] **J5.1** — Create `onboarding_gluconav_page_body.dart` widget (Diabetes Type, HbA1c band, Cuisine, Diet — 4 pickers)
- [x] **J5.2** — Add the new page to `onboarding_screen.dart` flow (after current page 4, before overview)
- [x] **J5.3** — Extend `OnboardingBloc.userSelection` with `diabetesType`, `hbA1cBand`, `cuisinePreference`, `dietType`
- [x] **J5.4** — Create `gluconav_api_service.dart` (http wrapper: `onboardUser`, `getRecommendations`, `logFeedback`, `logGlucose`)
- [x] **J5.5** — Wire onboarding submit → `POST /api/v1/users/onboard` → save `user_id` to SharedPreferences

### J6 — GlucoNav AI Dashboard Screen
- [x] **J6.1** — Create `gluconav_dashboard_bloc.dart` (events: `LoadDashboard`, `UpdateContext`; states: Loading/Loaded/Error)
- [x] **J6.2** — Create `gluconav_dashboard_screen.dart` (sleep slider, glucose field, meal type toggle)
- [x] **J6.3** — Meal + Exercise recommendation card widgets (spike badge, reason, "Done" button)
- [x] **J6.4** — Context warning banner + Coach mode chip in app bar
- [x] **J6.5** — Wire as 4th tab ("AI Suggest" icon) in `core/presentation/main_screen.dart`

### J7 — Order-of-Eating Pop-up
- [x] **J7.1** — Create `eating_sequence_sheet.dart` (`DraggableScrollableSheet`, numbered steps: 🥗→🥩→🍚)
- [x] **J7.2** — Add spike comparison display: "Without order: +67 mg/dL" vs "With order: +24 mg/dL"
- [x] **J7.3** — Trigger sheet from `diary_page.dart` when logged meal's carb ratio indicates high-GI

**✅ J-Phase 2 Done When:** App shows GlucoNav teal theme; onboarding collects diabetes fields and registers user; "AI Suggest" tab shows real recommendations from FastAPI; high-carb meal log triggers eating order sheet

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

| Session | Date       | Member | What was done                                                                                                                                                                                                                                        |
| ------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1       | 2026-04-04 | J      | Phase 0: Shared setup complete. Folder structure, backend (FastAPI/SQLAlchemy) and frontend (Flutter) boilerplates created. SQLite initialized. Dependency installation verified (noting lightfm requires C++ compiler).                             |
| 2       | 2026-04-04 | J      | J1 complete: meals.csv (65 rows), exercises.csv (30 rows), synthetic_users.csv (200 rows) all verified. Seed data ready for J2.                                                                                                                      |
| 3       | 2026-04-04 | J      | J2 complete: data_generator.py (8112 meal + 3973 exercise interactions), feature_builder.py (23 user / 24 meal / 24 exercise features). exercises.csv re-saved with proper quoting.                                                                  |
| 4       | 2026-04-04 | J      | Phase 1 complete: J3 (Model Training) and J4 (Prediction Services) finished. Models trained with logistic loss and verified with test_recommend.py.                                                                                                  |
| 5       | 2026-04-04 | J      | Phase 2 replanned: OpenNutriTracker (ONT) adopted as Flutter base. New tasks J0/J5/J6/J7 defined. TEAM_PLAN.md and implementation_plan.md updated. ONT uses BLoC/Provider/Hive — GlucoNav features added as new ONT features.                        |
| 6       | 2026-04-04 | J      | J5 complete: Diabetes Onboarding Extension. Created `onboarding_gluconav_page_body.dart` (4 pickers), integrated as page 5 in flow, extended `UserDataMaskEntity`, created `gluconav_api_service.dart`, wired submit to FastAPI + SharedPreferences. |
| 7       | 2026-04-04 | J      | J6 complete: AI Dashboard Screen wired. `GlucoNavDashboardBloc` registered in locator. `GlucoNavHomeScreen` added as 4th tab ("AI Suggest") in `main_screen.dart`. 4-tab nav: Home / Diary / AI Suggest / Profile.                                   |
| 8       | 2026-04-04 | J      | J7 complete: Order-of-Eating Pop-up. Created `eating_sequence_sheet.dart` with a 3-step tutorial and estimated spike impact. Hooked into `DayInfoWidget` to trigger when users tap a logged meal with high carb ratio.                               |

---

*Mark tasks `[/]` when starting, `[x]` when done. Always update `CONTEXT.md` after each session.*
