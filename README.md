# GlucoNav 🩺
> **Team:** J (ML) · K (Backend) · L (Frontend)
> **Personalized metabolic co-pilot for Indian diabetic patients**
> Team Innofusion | Medathon 2026

---

## ⚡ Quick Demo Run (3 commands)

```powershell
# Terminal 1 — Backend
cd C:\CHAINAIM3003\mcp-servers\Medathon\MetabollicOS\backend
conda activate gluconav && python run.py

# Terminal 2 — Frontend
cd C:\CHAINAIM3003\mcp-servers\Medathon\MetabollicOS\frontend\OpenNutriTracker
flutter run -d chrome
```

> **Backend down?** The app auto-falls back to rich mock data. Demo still works.

See **[DEMO_SCRIPT.md](./DEMO_SCRIPT.md)** for the full 8-step judge-facing demo with talking points, Q&A, and key numbers.

---

## First-Time Setup 

### Step 1 — Backend + Miniconda

```powershell
# Install Miniconda from https://docs.conda.io/en/latest/
conda create -n gluconav python=3.10
conda activate gluconav
conda install -c conda-forge lightfm
pip install -r backend/requirements.txt
```

### Step 2 — Environment Variables

```powershell
cd backend
copy .env.example .env
# Edit .env:
#   GOOGLE_AI_KEY=your_key_here    ← get free at aistudio.google.com
#   VISION_USE_STUB=1              ← set 0 only when HuggingFace model is downloaded
```

### Step 3 — Train ML Models (one-time, ~2 min)

```powershell
cd backend
python app/ml/data_generator.py   # generate interaction data
python app/ml/train_diet.py       # train diet model
python app/ml/train_exercise.py   # train exercise model
python test_recommend.py          # verify top-3 recs print correctly
```

### Step 4 — Seed Demo Users

```powershell
cd backend
python scripts/seed_demo.py       # creates demo_user_new + demo_user_experienced
python scripts/verify_demo.py    # runs 11 automated checks — should all pass ✅
```
*(Troubleshooting: If you encounter SQLite schema errors due to earlier model changes, simply delete `backend/gluconav.db` and re-run the seed commands above.)*

Expected `verify_demo.py` output:
```
✅ User row exists               [demo_user_new]
✅ UserProfile row exists
✅ No meal interactions (cold start)  [0 found]
✅ User row exists               [demo_user_experienced]
✅ ≥ 28 meal interactions (14 days × 2)  [~35 found]
✅ ≥ 14 glucose readings         [~20 found]
✅ Experienced user has more meal history than new user
✅ All checks passed — demo data is ready!
```

### Step 5 — Flutter

```powershell
cd frontend/OpenNutriTracker

# If flutter isn't in PATH:
where flutter                      # check if installed
$env:PATH = "C:\flutter\bin;" + $env:PATH   # add to session PATH

# Or use FVM (already configured in .fvmrc):
fvm install && fvm flutter pub get

flutter pub get
flutter run -d chrome
```

---

## Demo Script

See **[DEMO_SCRIPT.md](./DEMO_SCRIPT.md)** for:
- 8-step demo walkthrough with exact timing
- Talking points for each step
- Q&A cheat sheet for judges
- Backup plan (if backend is down)
- Coach mode demo (single-line code change)

### At a glance:

| Step | Tab              | Action                    | Key stat                                          |
| ---- | ---------------- | ------------------------- | ------------------------------------------------- |
| 1    | Onboarding       | Pick params               | Creates structured user record                    |
| 2    | Home             | Show Idli + Sambar as #1  | "+18 mg/dL predicted spike"                       |
| 3    | Profile → Home   | Switch new vs experienced | "59% better control after 14 days"                |
| 4    | Home             | Long Press Meal Card      | Smart Meal Swap popup shown                       |
| 5    | Home             | Tap "Scan My Plate"       | Camera opens                                      |
| 6    | Camera           | Pick food photo           | ViT detects items                                 |
| 7    | Sequence overlay | Show numbered badges      | "64% spike reduction with this order"             |
| 8    | Sequence overlay | Tap "Start Eating!"       | 20-min timer starts                               |
| 9    | Application      | Action Modal logging      | Track arbitrary exercise & food via bottom sheets |
| 10   | Profile          | Show TiR + streak         | "71% Time-in-Range, 12-day streak"                |
---

## API Endpoints

| Method | Endpoint                      | Description                                                   |
| ------ | ----------------------------- | ------------------------------------------------------------- |
| POST   | `/api/v1/users/onboard`       | Register + diabetes profile                                   |
| GET    | `/api/v1/recommend/{user_id}` | Personalized recs (diet + exercise + spike_risk + coach_mode) |
| POST   | `/api/v1/feedback`            | Log interaction (requires user_id)                            |
| POST   | `/api/v1/glucose-reading`     | Log glucometer reading                                        |
| POST   | `/api/v1/analyze-meal`        | Photo → ViT detection + Gemini sequence                       |
| GET    | `/api/v1/meals`               | 65-item Indian meal catalog                                   |
| GET    | `/api/v1/exercises`           | 30-item exercise catalog                                      |
| GET    | `/health`                     | Health check                                                  |

Full docs: `http://localhost:8000/docs` (Swagger UI)

---

## Environment Variables (`backend/.env`)

```env
GOOGLE_AI_KEY=your_gemini_api_key_here   # aistudio.google.com — free
DATABASE_URL=sqlite:///./gluconav.db
MODEL_PATH=app/ml/models/
DEBUG=True
VISION_USE_STUB=1   # 1 = stub responses (fast demo) | 0 = real ViT + Gemini
```

---

## Architecture

```
backend/app/
├── main.py               CORS allow_origins=["*"]
├── models/               user (id/email/name/age), meal (glucose_delta),
│                         exercise, glucose (dual field)
├── schemas/              feedback (user_id required), glucose (dual field)
├── routers/              users, recommendations, feedback, glucose,
│                         meals, exercises, vision
└── services/             diet_engine, exercise_engine, recommendation_service,
                          context_service, burnout_service,
                          vision_service (ViT), sequence_service (Gemini)

backend/scripts/
├── seed_demo.py          Seeds demo_user_new (cold) + demo_user_experienced (14d)
└── verify_demo.py        11 automated checks — run after seeding

frontend/OpenNutriTracker/lib/
├── main.dart             3-tab shell + Custom SharedPreferences Boot router
├── services/             gluconav_api_service.dart (real→mock fallback)
└── features/             dashboard, sequence, activity, trends (Profile), onboarding
```

---

## Integration Notes

| Concern                  | Resolution                                                              |
| ------------------------ | ----------------------------------------------------------------------- |
| CORS                     | `allow_origins=["*"]` in `main.py`                                      |
| Flutter web image upload | `MultipartFile.fromBytes()` + `MediaType('image','jpeg')`               |
| Backend unreachable      | Auto-fallback to mock JSON                                              |
| User ID persistence      | SharedPreferences — forces Onboarding if empty                          |
| Demo user switching      | Profile tab shortcuts (bottom list)                                     |
| Real-time spike_risk     | sleepScore + currentGlucose passed to `/recommend` query params         |
| SQLite FKs               | MealInteraction + ExerciseInteraction use soft FKs (no hard constraint) |

---

*GlucoNav — not a tracker, a metabolic co-pilot.*
*Built by Team Innofusion for Medathon 2026.*
