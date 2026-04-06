import requests
import time
import random
import math

# --- Configuration ---
# Use the demo user ID the app is currently showing
USER_ID = "demo_user_experienced" 
# When running on the same machine, 'localhost' works.
# When running from another device, use the server's IP (e.g., '192.168.1.XX')
BASE_URL = "http://10.240.206.169:8000/api/v1"

def simulate_cgm():
    print(f"🚀 [GlucoNav] CGM SIMULATOR STARTING...")
    print(f"📡 Target User: {USER_ID}")
    print(f"🔗 API Endpoint: {BASE_URL}/glucose-reading")
    print("--------------------------------------------------")
    
    t = 0
    while True:
        # Create a realistic glucose curve using a sine wave + random noise
        # Ranges from ~80 to ~180 mg/dL
        base = 130 + (50 * math.sin(t / 20)) 
        glucose = round(base + random.uniform(-3, 3), 1)
        
        payload = {
            "user_id": USER_ID,
            "glucose_mgdl": glucose
        }
        
        try:
            r = requests.post(f"{BASE_URL}/glucose-reading", json=payload)
            if r.status_code == 200:
                # Visual indicator for the terminal
                tag = "🟢 STABLE"
                if glucose > 170: tag = "🔴 SPIKE"
                elif glucose < 90: tag = "🔵 LOW"
                
                print(f"[{tag}] Sent: {glucose} mg/dL | Time: {time.strftime('%H:%M:%S')}")
            else:
                print(f"❌ API Error: {r.status_code} - {r.text}")
        except Exception as e:
            print(f"⚠️ Connection Error: {e}")
            print("👉 Check if your FastAPI backend (run.py) is running!")
            
        t += 1
        time.sleep(10) # Update every 10 seconds for the demo

if __name__ == "__main__":
    simulate_cgm()
