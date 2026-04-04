# GlucoNav — Team Plan
> **For Medathon 2026 | Team Innofusion**
> Last updated: 2026-04-05

---

## Team Members

| ID           | Role              | Focus Area                                                 |
| ------------ | ----------------- | ---------------------------------------------------------- |
| **Member J** | ML Engineer       | Recommendation Engine (LightFM, data, prediction services) |
| **Member K** | Backend Engineer  | FastAPI, Vision AI, Burnout service, DB models             |
| **Member L** | Frontend Engineer | Flutter UI, all screens, BLoC providers, API wiring        |

> **Phases 3–6 split:** Member K owns all backend tracks; Member L owns all frontend/UI tracks. Both work in parallel and integrate in Phase 6.5.

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

## ╔ PARALLEL DEVELOPMENT — Phase 3 → Phase 5 ╗
> ⚡ **Member K and Member L work fully independently on their own track.  
> No blocking dependencies between K-Track and L-Track until Phase 6.5.**  
> - **K-Track** = all backend services + API endpoints  
> - **L-Track** = all Flutter screens + UI logic (use hardcoded mock JSON until integration)

---

## ║ K-TRACK — Backend: Phases 3–5 (Member K works independently) ║

### K4 — Vision + LLM Backend (Phase 3 — Backend)
- [x] **K4.1** — `services/vision_service.py` — ViT food detection (DrishtiSharma HuggingFace model)
- [x] **K4.2** — `services/sequence_service.py` — Gemini 1.5 Flash eating sequence generation
- [x] **K4.3** — `routers/vision.py` — `POST /api/v1/analyze-meal`

**✅ K4 Done When:** `POST /api/v1/analyze-meal` with an image returns `{detected_items, eating_sequence}` JSON

### K5 — Spike Risk Service (Phase 4 — Backend)
- [/] **K5.1** — `services/context_service.py` — `calculate_spike_risk(gi, sleep_score, steps, current_glucose)` returning risk level (low/medium/high)
- [ ] **K5.2** — Wire `calculate_spike_risk()` into `GET /api/v1/recommend/{user_id}` response payload as `spike_risk` field

**✅ K5 Done When:** `/recommend` response includes `spike_risk` field; context_service unit-tested

### K6 — Burnout Shield Backend (Phase 5 — Backend)
- [ ] **K6.1** — `services/burnout_service.py` — `calculate_burnout_score()` using skipped interactions + consecutive HIIT days
- [ ] **K6.2** — `get_coach_mode(burnout_score)` → returns `"active"` / `"balanced"` / `"supportive"`
- [ ] **K6.3** — Include `coach_mode` + `burnout_score` in `GET /api/v1/recommend/{user_id}` response

**✅ K6 Done When:** `/recommend` response includes `coach_mode` and `burnout_score`; tested with Swagger UI

### K7 — Backend Demo Seeds (Phase 6 — Backend)
- [ ] **K7.1** — `scripts/seed_demo.py` — seed `demo_user_new` (no interaction history)
- [ ] **K7.2** — Seed `demo_user_experienced` (14-day simulated interactions via data_generator)
- [ ] **K7.3** — Verify `/recommend/demo_user_new` vs `/recommend/demo_user_experienced` return visibly different results

**✅ K-Track Done When:** All K4–K7 tasks checked. Backend is fully integration-ready.**

---

## ║ L-TRACK — Frontend: Phases 3–5 (Member L works independently) ║

> 💡 Use hardcoded mock JSON responses while K-Track is incomplete. Replace with real API calls in Phase 6.5.

### L6 — Sequence Navigator UI (Phase 3 — Frontend)
- [ ] **L6.1** — `screens/sequence/camera_screen.dart` — image_picker (camera + gallery) → loading spinner → mock POST
- [ ] **L6.2** — `screens/sequence/sequence_overlay_screen.dart` — display meal photo + numbered badges over food items
- [ ] **L6.3** — Numbered step list (food name + reason per step: e.g. "1. Salad — start with fiber")
- [ ] **L6.4** — Spike comparison cards ("Without order: +67 mg/dL" vs "With order: +24 mg/dL") + "Start Eating!" CTA button
- [ ] **L6.5** — Wire "Scan My Plate" entry point from `gluconav_dashboard_screen.dart`

**✅ L6 Done When:** Full UI flow works with mock JSON: camera → overlay → sequence list → comparison cards

### L7 — Activity Snack UI (Phase 4 — Frontend)
- [ ] **L7.1** — 20-min post-meal background timer triggered after "Log this meal" tap (use `Timer` + in-app snackbar at T+20)
- [ ] **L7.2** — `screens/activity/activity_snack_screen.dart` — exercise card appears at 20-min mark (exercise name, duration, glucose benefit badge)
- [ ] **L7.3** — "Done!" button → call `gluconav_api_service.logFeedback(exercise_id)` → trigger streak +1 update in BLoC
- [ ] **L7.4** — Integrate `spike_risk` field from mock recommendation response to conditionally show urgency level on card

**✅ L7 Done When:** Tapping "Log meal" starts timer; at 20 min, Activity Snack screen appears with correct exercise

### L8 — Burnout Shield Frontend (Phase 5 — Frontend)
- [ ] **L8.1** — Read `coach_mode` + `burnout_score` from recommendation response (mock)
- [ ] **L8.2** — `active` mode: normal UI with performance badges
- [ ] **L8.3** — `balanced` mode: neutral language, hide streak pressure indicators
- [ ] **L8.4** — `supportive` mode: softer copy ("You're doing great 💚"), hide red warnings, show encouraging emojis
- [ ] **L8.5** — Animate coach-mode chip in `gluconav_dashboard_screen.dart` app bar

**✅ L8 Done When:** Changing `coach_mode` in mock JSON visibly changes app tone across all recommendation screens

### L9 — Frontend Demo Polish (Phase 6 — Frontend)
- [ ] **L9.1** — Test complete 8-step demo script flow in Chrome
- [ ] **L9.2** — Trends screen: display 71% Time-in-Range + 12-day streak badge
- [ ] **L9.3** — Fix any UI jank, loading states, or missing error states

**✅ L-Track Done When:** All L6–L9 tasks checked. Frontend demo flows without errors.**

---

## PHASE 6.5 — Integration (Member K + Member L — do TOGETHER after both tracks are done)

> 🔗 **This phase happens once K-Track AND L-Track are both complete. Both members work together.**

- [ ] **I1.1** — Replace all L-Track mock JSON with real API calls in `gluconav_api_service.dart`
  - `POST /api/v1/analyze-meal` → replace camera screen mock
  - `GET /api/v1/recommend/{user_id}` → ensure `spike_risk` + `coach_mode` + `burnout_score` fields consumed
- [ ] **I1.2** — End-to-end test: Onboarding → Dashboard → Scan Plate → Sequence → Log Meal → Activity Snack
- [ ] **I1.3** — End-to-end test: Demo user new vs experienced (personalization delta visible)
- [ ] **I1.4** — CORS / network errors resolved between Flutter web and FastAPI
- [ ] **I1.5** — `flutter run -d chrome` + `python run.py` — full app works together

**✅ Integration Done When:** All I1.x tasks checked; full 8-step demo runs without mocks.**

---

## PHASE 6 — Demo Preparation (All three — after Integration)

> ⚠️ S1.1 and S1.2 require K7 (backend demo seeds) to be done first.

- [ ] **S1.1** — Seed `demo_user_new` (zero interaction history → generic recommendations) ← requires K7.1
- [ ] **S1.2** — Seed `demo_user_experienced` (14-day history → personalized recommendations) ← requires K7.2
- [ ] **S1.3** — Test 8-step demo script end-to-end
- [ ] **S1.4** — Side-by-side comparison: new vs experienced user recommendations confirmed
- [ ] **S1.5** — Record / rehearse demo flow for judges

---

## Build Order

```
Phase 0 (Shared Setup — all three)
  ↓
Phase 1 (J: ML Engine — standalone, no API/Flutter needed)
  ↓
Phase 2 (K: FastAPI  +  J: Flutter Integration — run in parallel)
  ↓
╔══════════════════════════════════════════════════════════════╗
║      PARALLEL DEVELOPMENT (Phase 3 → Phase 5)               ║
║                                                              ║
║  Member K (Backend):        Member L (Frontend):             ║
║  ┌─────────────────┐        ┌─────────────────┐             ║
║  │ K4: Vision+LLM  │        │ L6: Sequence UI  │             ║
║  │   Backend       │        │   (mock data)    │             ║
║  ├─────────────────┤        ├─────────────────┤             ║
║  │ K5: Spike Risk  │        │ L7: Activity     │             ║
║  │   Service       │        │   Snack UI       │             ║
║  ├─────────────────┤        ├─────────────────┤             ║
║  │ K6: Burnout     │        │ L8: Burnout      │             ║
║  │   Backend       │        │   Shield UI      │             ║
║  ├─────────────────┤        ├─────────────────┤             ║
║  │ K7: Demo Seeds  │        │ L9: Demo Polish  │             ║
║  └─────────────────┘        └─────────────────┘             ║
╚══════════════════════════════════════════════════════════════╝
  ↓  (both tracks complete)
Phase 6.5 (K + L together: Integration — replace mocks with real API calls)
  ↓
Phase 6 (All three: Demo Preparation, End-to-end Testing)
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
| 9       | 2026-04-05 | K+L    | TEAM_PLAN.md restructured for parallel development: Phases 3–5 split into K-Track (backend) and L-Track (frontend). Phase 6.5 (Integration) added as the merge point. K7/L9 demo tasks defined. Build Order diagram updated.                        |
| 10      | 2026-04-05 | K      | K4 complete: `vision_service.py` (lazy-load ViT pipeline, `detect_foods()`, stub fallback), `sequence_service.py` (Gemini 1.5 Flash prompt → structured JSON, stub fallback), `routers/vision.py` (`POST /api/v1/analyze-meal`, 10MB limit, content-type guard, `VISION_USE_STUB` flag), vision router wired into `main.py`. K5 (`context_service.py`) is next. |

---

*Mark tasks `[/]` when starting, `[x]` when done. Always update `CONTEXT.md` after each session.*
