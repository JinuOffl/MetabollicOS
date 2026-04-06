# GlucoNav 🩺 — Personalized Metabolic Co-Pilot

> **Team InnoFusion | Medathon 2026**  
> Real-time glucose monitoring + AI meal sequencing + personalized recommendations for Indian diabetic patients.

---

## 📋 Table of Contents

1. [What is GlucoNav?](#what-is-gluconav)
2. [System Architecture](#system-architecture)
3. [Prerequisites](#prerequisites)
4. [First-Time Environment Setup](#first-time-environment-setup)
5. [Running the Services (in order)](#running-the-services-in-order)
6. [Pairing the CGM Simulator](#pairing-the-cgm-simulator)
7. [API Reference](#api-reference)
8. [Troubleshooting](#troubleshooting)

---

## What is GlucoNav?

GlucoNav is a three-part system:

| Component | Technology | Purpose |
|---|---|---|
| **Backend** | FastAPI + SQLite + LightFM | REST API, ML recommendations, glucose logging |
| **Frontend** | Flutter (Web / Chrome) | Patient dashboard with real-time CGM chart |
| **CGM Simulator** | Flask + Web UI | Simulates a wearable glucose sensor pushing live data |

**Core features:**
- 🤖 **LightFM matrix factorization** — personalized meal & exercise recommendations
- 📸 **Gemini Vision** — scan your plate → get optimal eating order (Fiber → Protein → Carb)
- 📈 **Live CGM sync** — glucose readings auto-push from simulator to dashboard every 10s
- 🔢 **Insulin dose calculator** — auto-computes bolus for Type 1 patients
- 🎭 **Coach modes** — Active / Balanced / Supportive tone adapts to user's metabolic state

---

## System Architecture

```
┌──────────────────────────────────────────────────────┐
│  CGM Simulator  (Flask :5000)                        │
│  Pushes glucose readings every 10s via HTTP POST     │
└──────────────────────┬───────────────────────────────┘
                       │ POST /api/v1/glucose-reading
                       ▼
┌──────────────────────────────────────────────────────┐
│  Backend  (FastAPI :8000)                            │
│  SQLite DB · LightFM ML · Gemini Vision API         │
└──────────────────────┬───────────────────────────────┘
                       │ GET /api/v1/recommend/{user_id}
                       ▼
┌──────────────────────────────────────────────────────┐
│  Flutter Dashboard  (Chrome)                         │
│  Real-time chart · Meal cards · Activity tracker     │
└──────────────────────────────────────────────────────┘
```

---

## Prerequisites

Install these **before** starting:

| Tool | Version | Download |
|---|---|---|
| **Miniconda** (or Anaconda) | Any | https://docs.conda.io/en/latest/miniconda.html |
| **Flutter SDK** | ≥ 3.19 | https://docs.flutter.dev/get-started/install/windows |
| **Google Chrome** | Any | https://www.google.com/chrome |
| **Git** | Any | https://git-scm.com |

You also need a **free Gemini API key**:
1. Go to → https://aistudio.google.com/app/apikey
2. Click **"Create API key"**
3. Copy and save it — you'll paste it in Step 3 below.

---

## First-Time Environment Setup

> ⚠️ Run each step **from the root of the project** unless stated otherwise.  
> Root = the folder containing `backend/`, `frontend/`, `README.md`.

---

### Step 1 — Clone the Repository

```powershell
git clone https://github.com/<your-username>/MetabollicOS.git
cd MetabollicOS
```

---

### Step 2 — Create the Python Environment

```powershell
# Create a conda environment with Python 3.10
conda init powershell (in anaconda command prompt)
conda create -n gluconav python=3.10 -y
conda activate gluconav

# Install LightFM (ML recommendation engine — needs C++ build tools)
conda install -c conda-forge lightfm -y

# Install all other backend dependencies
pip install -r backend/requirements.txt

# Install Flask and requests (needed for the CGM simulator)
pip install flask requests pillow
```

> **If `conda install lightfm` fails on Windows:**  
> Install Visual Studio Build Tools first → https://visualstudio.microsoft.com/visual-cpp-build-tools/  
> Then retry `conda install -c conda-forge lightfm`

---

### Step 3 — Configure Environment Variables

```powershell
# Go into the backend folder
cd backend

# Copy the example env file
copy .env.example .env
```

Now open `backend/.env` in any text editor and fill in your values:

```env
GOOGLE_AI_KEY=paste_your_gemini_api_key_here
DATABASE_URL=sqlite:///./gluconav.db
MODEL_PATH=app/ml/models/
DEBUG=True
```

> **Where to get the key:** https://aistudio.google.com/app/apikey (free, no credit card)

---

### Step 4 — Train the ML Models *(one-time, ~2 minutes)*

```powershell
# Still inside the backend/ folder
python app/ml/data_generator.py    # generates synthetic interaction data
python app/ml/train_diet.py        # trains the meal recommendation model
python app/ml/train_exercise.py    # trains the exercise recommendation model
python test_recommend.py           # verify output — should print top-3 meals
```

Expected output from `test_recommend.py`:
```
✅  Top-3 Diet Recommendations for demo user:
  1. Sprouts Salad        (+16 mg/dL)
  2. Roasted Chana        (+16 mg/dL)
  3. Oats Upma            (+18 mg/dL)
```

---

### Step 5 — Seed the Demo Users *(one-time)*

```powershell
# Still inside the backend/ folder
python scripts/seed_demo.py      # creates demo_user_new + demo_user_experienced
python scripts/verify_demo.py    # runs 11 automated checks
```

Expected output from `verify_demo.py`:
```
✅ User row exists               [demo_user_new]
✅ UserProfile row exists
✅ No meal interactions (cold start)  [0 found]
✅ User row exists               [demo_user_experienced]
✅ ≥ 28 meal interactions (14 days × 2)  [~35 found]
✅ ≥ 14 glucose readings         [~20 found]
✅ All checks passed — demo data is ready!
```

> 💡 **If you see SQLite schema errors**, delete `backend/gluconav.db` and rerun both scripts.

---

### Step 6 — Set Up the Flutter Frontend

```powershell
# Go to the Flutter project
cd frontend/OpenNutriTracker
set the below in terminal :

$env:PATH = "C:\flutter\bin;" + $env:PATH

flutter pub get
```

Verify Flutter is working:
```powershell
flutter doctor    # should show Chrome as a connected device
```

---

### Step 7 — Update the IP Address

> ⚠️ **Critical for devices on the same Wi-Fi network.**  
> If running everything on **one laptop**, skip this — `localhost` won't work from Chrome on web; use your **local network IP**.

**Find your IP address:**
```powershell
ipconfig
# Look for: IPv4 Address under your Wi-Fi adapter
# Example: 192.168.1.42
```

**Update it in two files:**

**File 1:** `frontend/OpenNutriTracker/lib/services/gluconav_api_service.dart`  
Line 29 — change the IP:
```dart
// Before:
static String _base = 'http://10.240.206.169:8000/api/v1';

// After (your IP):
static String _base = 'http://192.168.1.42:8000/api/v1';
```

**File 2:** `backend/scripts/cgm_web_simulator.py`  
Line 10 — change the IP:
```python
# Before:
SERVER_IP = "10.240.206.169"

# After (your IP):
SERVER_IP = "192.168.1.42"
```

---

## Running the Services (in order)

> Open **3 separate PowerShell/terminal windows** at the project root. Run each command in its own window.

### Terminal 1 — Backend (Start This First)

```powershell
conda activate gluconav
cd backend
python run.py
```

✅ **Ready when you see:**
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Interactive API docs available at: `http://localhost:8000/docs`

---

### Terminal 2 — Flutter Dashboard

```powershell
cd frontend/OpenNutriTracker
flutter run -d chrome
```

✅ **Ready when Chrome opens** with the GlucoNav onboarding or dashboard.

> On first launch it shows **Onboarding** (enter name, select diabetes type, etc).  
> After onboarding, you land on the **AI Dashboard** showing meal and activity recommendations.

---

### Terminal 3 — CGM Simulator

```powershell
conda activate gluconav
python backend/scripts/cgm_web_simulator.py
```

✅ **Ready when you see:**
```
 * Running on http://0.0.0.0:5000
```

Open the Simulator UI: `http://localhost:5000` (or `http://<your-ip>:5000` from another device)

---

## Pairing the CGM Simulator

The simulator and the dashboard talk to each other via a **Device Pairing ID**.

### Step-by-step

**1. Find the Pairing ID in the Flutter App**

Scroll to the very bottom of the AI Dashboard.  
You will see:

```
DEVICE PAIRING ID
demo_user_experienced
```

Copy that ID.

**2. Paste it into the CGM Simulator**

- Open `http://localhost:5000` in a browser
- Find the **"Device Pairing ID"** input box (2 places)
- Paste the ID and press **"Link Device"** (or **Enter**)

**3. Confirm the Link**

The simulator will show:
```
✅ Linked to: demo_user_experienced
Pushing glucose every 10 seconds...
```

The Flask server terminal will print:
```
POST /api/v1/glucose-reading HTTP/1.1  200 OK
```

**4. Watch the Dashboard Update**

The glucose chart on the Flutter dashboard auto-refreshes every 10 seconds.  
You will see the live glucose value and trend line update in real time.

> 💡 **Spike Demo:** In the simulator UI, press the **"⚡ Trigger Spike"** button to send a 245 mg/dL reading. The Flutter dashboard will immediately show the red "High glucose" alert.

---

## API Reference

Base URL: `http://localhost:8000/api/v1`  
Swagger UI: `http://localhost:8000/docs`

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/users/onboard` | Register user with diabetes profile |
| `GET` | `/recommend/{user_id}` | Get personalized meal + exercise recommendations |
| `POST` | `/feedback` | Log user interaction (completed, skipped, liked) |
| `POST` | `/glucose-reading` | Log a glucose reading (used by CGM simulator) |
| `POST` | `/analyze-meal` | Upload plate photo → Gemini detects foods + optimal eating order |
| `GET` | `/meals` | Full 65-item Indian meal catalog |
| `GET` | `/exercises` | Full 30-item exercise catalog |
| `GET` | `http://localhost:8000/health` | Health check |

---

## Troubleshooting

### ❌ `ImportError: No module named 'lightfm'`
```powershell
conda activate gluconav
conda install -c conda-forge lightfm -y
```

### ❌ Meal cards show no images / wrong images
The app uses Unsplash food photos. Ensure you have internet access — images load from `images.unsplash.com`.

### ❌ `Food detection failed: 404 models/gemini-...`
Your `GOOGLE_AI_KEY` in `backend/.env` is missing or incorrect.  
Get a free key at: https://aistudio.google.com/app/apikey

### ❌ Glucose chart not updating in real time
1. Check the Pairing ID matches exactly (case-sensitive)
2. Confirm Terminal 3 (CGM simulator) is running
3. Confirm Terminal 1 (backend) prints `200 OK` for `POST /glucose-reading`

### ❌ Flutter shows "Analysis failed" when scanning plate
The backend must be running (Terminal 1). Check the IP in `gluconav_api_service.dart` matches your machine's actual IP from `ipconfig`.

### ❌ SQLite errors on startup
```powershell
# Delete the database and re-seed
del backend\gluconav.db
cd backend
python scripts/seed_demo.py
```

### ❌ `flutter run` can't find Chrome
```powershell
flutter config --enable-web
flutter run -d chrome
```

---

## Project Structure

```
MetabollicOS/
├── backend/
│   ├── app/
│   │   ├── main.py               # FastAPI app, CORS config
│   │   ├── models/               # SQLAlchemy DB models
│   │   ├── schemas/              # Pydantic request/response schemas
│   │   ├── routers/              # API endpoints (users, recommend, vision…)
│   │   ├── services/             # Business logic (diet_engine, vision_service…)
│   │   └── ml/
│   │       ├── data_generator.py # Generates synthetic training data
│   │       ├── train_diet.py     # Trains LightFM meal model
│   │       ├── train_exercise.py # Trains LightFM exercise model
│   │       └── models/           # Saved .pkl model files (after training)
│   ├── data/
│   │   ├── meals.csv             # 65 Indian meals with GI, macros, image URLs
│   │   └── exercises.csv         # 30 exercises with glucose benefit scores
│   ├── scripts/
│   │   ├── seed_demo.py          # Creates demo users with 14-day history
│   │   ├── verify_demo.py        # Validates demo data integrity
│   │   └── cgm_web_simulator.py  # Flask CGM device simulator + web UI
│   ├── .env                      # ← Your secrets (not committed to git)
│   ├── .env.example              # Template for .env
│   ├── requirements.txt          # Python dependencies
│   └── run.py                    # Uvicorn launcher
│
└── frontend/OpenNutriTracker/
    └── lib/
        ├── main.dart             # App entry point, routing
        ├── services/
        │   └── gluconav_api_service.dart  # ← Change IP here
        └── features/
            ├── gluconav_dashboard/   # Main AI dashboard
            ├── sequence/             # Plate scan + eating order overlay
            ├── activity/             # Activity snack screen
            ├── trends/               # Profile + glucose trends
            └── onboarding/           # First-time user setup
```

---

*GlucoNav — not a tracker, a metabolic co-pilot.*  
*Built by Team Innofusion for Medathon 2026.*
