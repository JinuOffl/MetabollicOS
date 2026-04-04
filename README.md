# GlucoNav 🩺
> **Team:** J (ML) · K (Backend) · L (Frontend)
> **Personalized metabolic co-pilot for Indian diabetic patients**  
> Team Innofusion | Medathon 2026

---

## What Is This?

GlucoNav is a **metabolic recommendation engine** — like Netflix's recommendation system, but for blood sugar management. It learns each user's unique glucose response patterns and recommends:

- 🍽️ **What to eat** (ranked by predicted glucose spike for *that* user)
- 🔢 **In what order** (Fiber → Protein → Carbs = 38–73% spike reduction)
- 🚶 **What micro-exercise** to do post-meal to flatten the spike

Built for **101 million Indians with diabetes** — works with basic glucometers, no expensive CGM required.

---

## Quick Links

| File                                                     | Purpose                                                |
| -------------------------------------------------------- | ------------------------------------------------------ |
| [CONTEXT.md](./CONTEXT.md)                               | Project state — what's done, what's not, key decisions |
| [TEAM_PLAN.md](./TEAM_PLAN.md)                           | Phase-by-phase checklist for Member J and Member M     |
| [GlucoNav_Master_Prompt.md](./GlucoNav_Master_Prompt.md) | Complete technical spec (hand to any AI to build)      |

---

## Tech Stack

| Layer          | Technology                                               |
| -------------- | -------------------------------------------------------- |
| Frontend       | Flutter (Dart) — Android + iOS + Web                     |
| Backend        | FastAPI (Python 3.11)                                    |
| Recommendation | LightFM 1.17 (Matrix Factorization)                      |
| Food Vision AI | DrishtiSharma/finetuned-ViT-IndianFood-Classification-v3 |
| LLM            | Gemini 1.5 Flash (eating sequence generation)            |
| Database       | SQLite (dev) → PostgreSQL (prod)                         |
| State Mgmt     | Riverpod (Flutter)                                       |

---

## Project Structure

```
gluconav/
├── CONTEXT.md            ← Read this to understand current project state
├── TEAM_PLAN.md          ← Task checklist for both team members
├── README.md             ← This file
├── GlucoNav_Master_Prompt.md  ← Full technical spec
│
├── backend/
│   ├── app/
│   │   ├── main.py       ← FastAPI entry point
│   │   ├── models/       ← SQLAlchemy DB models
│   │   ├── schemas/      ← Pydantic request/response schemas
│   │   ├── routers/      ← API route handlers
│   │   ├── services/     ← Business logic (engines, vision, burnout)
│   │   └── ml/           ← LightFM training scripts + saved models
│   ├── data/             ← meals.csv, exercises.csv, synthetic_users.csv
│   ├── tests/
│   ├── .env              ← GOOGLE_AI_KEY, DATABASE_URL
│   ├── requirements.txt
│   └── run.py
│
└── frontend/
    ├── lib/
    │   ├── main.dart
    │   ├── router.dart
    │   ├── models/
    │   ├── providers/
    │   ├── services/
    │   └── screens/
    └── pubspec.yaml
```

---

## Prerequisites

### Backend
- Python 3.11+
- pip

### Frontend
- Flutter SDK (latest stable)
- Android Studio or VS Code with Flutter extension
- Chrome (for web demo)

---

## Setup & Run

### 1. Clone / Open Project

```bash
cd d:/Medathon/GlucoNav
```

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Mac/Linux

# Install dependencies
pip install -r requirements.txt

# Set up environment variables
copy .env.example .env
# Edit .env — add your GOOGLE_AI_KEY (Gemini API key)

### 3. ML Environment Setup (Miniconda)
`lightfm` requires a C++ compiler on Windows. To bypass build errors, we use **Miniconda**.

1. **Install Miniconda**: Download from [conda.io](https://docs.conda.io/en/latest/).
2. **Setup Environment**:
```powershell
# Verify installation
conda --version

# Create environment
conda create -n gluconav python=3.10

# Activate environment
conda activate gluconav

# Install LightFM
conda install -c conda-forge lightfm

# Initialize shell (restart terminal after)
conda init powershell
```
3. **Install Other Dependencies**:
```powershell
pip install -r backend/requirements.txt
```
# You can temporarily comment out lightfm to verify the FastAPI boot.
```

### 3. Recommendation Engine (Phase 1)
To train the models and verify the engine:
```powershell
cd backend
# Train models
python app/ml/data_generator.py
python app/ml/train_diet.py
python app/ml/train_exercise.py

# Verify (should print top-3 meals and exercises for a test user)
python test_recommend.py
```

### 4. Start Backend Server

```bash
python run.py
# FastAPI running at: http://localhost:8000
# Swagger API docs: http://localhost:8000/docs
```

### 5. Frontend Setup

```bash
cd frontend

flutter pub get

# Run on connected device
flutter run

# Run in Chrome (for demo)
flutter run -d chrome
```

---

## Environment Variables

Create `backend/.env` with:

```env
GOOGLE_AI_KEY=your_gemini_api_key_here
DATABASE_URL=sqlite:///./gluconav.db
MODEL_PATH=app/ml/models/
DEBUG=True
```

Get a free Gemini API key at: https://aistudio.google.com/app/apikey

---

## API Endpoints

| Method | Endpoint                      | Description                               |
| ------ | ----------------------------- | ----------------------------------------- |
| POST   | `/api/v1/users/onboard`       | Register user + profile                   |
| GET    | `/api/v1/recommend/{user_id}` | Get personalized recommendations          |
| POST   | `/api/v1/feedback`            | Log meal/exercise interaction             |
| POST   | `/api/v1/glucose-reading`     | Log glucose reading                       |
| POST   | `/api/v1/analyze-meal`        | Vision AI — detect food + eating sequence |
| GET    | `/api/v1/meals`               | Browse meal catalog                       |
| GET    | `/api/v1/exercises`           | Browse exercise catalog                   |

Full docs at `http://localhost:8000/docs` when backend is running.

---

## Demo Script (for Judges)

1. Open app → Onboarding (Priya, Type 2, South Indian, Vegetarian)
2. Home screen → shows "Idli + Sambar" as #1 with "+18 mg/dL"
3. Tap "Scan My Plate" → photograph a thali → numbered overlay appears
4. Show "Eating in this order reduces your spike by **64%**"
5. Log meal → 20-min timer starts
6. (Pre-staged) Activity Snack card: "3-min walk → -20 mg/dL"
7. Switch to `demo_user_experienced` → show personalized vs generic side-by-side
8. Trends screen → 71% Time-in-Range + 12-day streak

---

## For AI Assistants — How to Continue Work

Read these files in order before doing anything:
1. **[CONTEXT.md](./CONTEXT.md)** — current state, what's done/not done
2. **[TEAM_PLAN.md](./TEAM_PLAN.md)** — find your task (Member J / K / L), mark `[/]` when starting
3. **[README.md](./README.md)** — this file, for setup

After every successful code change:
1. Mark the task `[x]` in `TEAM_PLAN.md`
2. Update the relevant section in `CONTEXT.md`
3. If setup/run steps changed, update `README.md`

---

*GlucoNav — not a tracker, a metabolic co-pilot.*  
*Built by Team Innofusion for Medathon 2026.*
