# 🚀 GlucoNav: Live Demo & Team Setup Guide

This document outlines how to run the **Live CGM Simulation** and how a new team member can set up the project from scratch.

---

## 🏗️ 1. Global Setup (New Team Members)

If you just pulled this code, follow these steps to get the environment ready:

### **A. Backend Setup**
1.  **Conda Environment**:
    ```powershell
    conda create -n gluconav python=3.10
    conda activate gluconav
    ```
2.  **Dependencies**:
    ```powershell
    cd backend
    pip install -r requirements.txt
    pip install flask requests # Needed for the live simulator
    ```
3.  **Environment Variables**:
    Ensure `backend/.env` exists with your Gemini API key:
    ```text
    GEMINI_API_KEY=your_key_here
    DATABASE_URL=sqlite:///./gluconav.db
    ```

### **B. Frontend Setup**
1.  **Flutter SDK**: Ensure Flutter is installed and in your PATH.
2.  **Packages**:
    ```powershell
    cd frontend/OpenNutriTracker
    flutter pub get
    ```

---

## 🎥 2. How to Run the "Metabolic Demo" (3 Terminals)

To show the live-syncing dashboard, you must run all three components simultaneously.

### **Terminal 1: The Engine (Backend)**
Starts the FastAPI server and the SQLite database.
```powershell
cd backend
python run.py
```
*Note: The server is configured to listen on `0.0.0.0:8000` so other devices on Wi-Fi can connect.*

### **Terminal 2: The Interface (Flutter Dashboard)**
Launches the patient dashboard in Chrome.
```powershell
cd frontend/OpenNutriTracker
flutter run -d chrome
```
*Note: Refresh the page every 10s or check the bottom of the screen for your **Device Pairing ID**.*

### **Terminal 3: The Sensor (CGM Web Hub)**
Starts the beautiful "Secondary Device" UI and simulates live glucose.
```powershell
python backend/scripts/cgm_web_simulator.py
```
*   **Access the Sensor Hub**: Open `http://10.240.206.169:5000` in your browser.
*   **Pairing**: Paste the **Device Pairing ID** from the Flutter App into the hub's input box to link the data streams.

---

### **3. Key Files & Changes Made**
| Category | File | Description |
| :--- | :--- | :--- |
| **Simulator** | `backend/scripts/cgm_web_simulator.py` | Standalone device with a JS chart and "Pairing Box". |
| **Sync Logic** | `backend/app/routers/recommendations.py` | Backend now pulls the **latest** glucose from DB if no slider was touched. |
| **Refresh** | `.../gluconav_dashboard_bloc.dart` | Added a **10-second timer pulse** to auto-refresh recommendations. |
| **UI Support** | `.../gluconav_dashboard_screen.dart` | Added **"DEVICE PAIRING ID"** display at the bottom of the dashboard. |

---

### **⚠️ Important Medathon Tips**
*   **Same Wi-Fi**: Both devices (Simulator & App) MUST be on the same network.
*   **IP Address**: Always check your laptop's IP (`ipconfig`) and update it in `gluconav_api_service.dart` and `cgm_web_simulator.py` before the demo starts.
*   **Real-Time Proof**: Show the judges the graph on Device B and the numbers matching on Device C (the App). This proves the data is flowing through your decentralized architecture.
