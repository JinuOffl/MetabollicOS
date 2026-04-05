import flask
from flask import Flask, render_template_string, request, jsonify
import requests
import threading
import time
import random
import math

# --- CONFIGURATION ---
SERVER_IP = "10.242.238.169" # Main Backend IP
USER_ID = "c48edd6f-727f-48f1-be3b-158e5a3cb38c" # Default

app = Flask(__name__)

# Shared state between background thread and web UI
glucose_history = [] 

def background_simulator():
    """Tireless background loop to push data to the main backend."""
    t = 0
    while True:
        # Realistic Glucose Wave (80 to 200 mg/dL)
        base = 140 + (60 * math.sin(t / 20)) 
        val = round(base + random.uniform(-4, 4), 1)
        # Keep within bounds
        val = max(70, min(240, val))
        
        entry = {"time": time.strftime("%H:%M:%S"), "value": val}
        glucose_history.append(entry)
        
        # Keep last 20 readings for the chart
        if len(glucose_history) > 20: glucose_history.pop(0)

        # Push to Main Backend
        api_url = f"http://{SERVER_IP}:8000/api/v1/glucose-reading"
        payload = {"user_id": USER_ID, "glucose_mgdl": val}
        
        try:
            requests.post(api_url, json=payload, timeout=2)
            # print(f"📡 Pushed {val} to ID: {USER_ID}")
        except Exception:
            pass # Keep simulator alive

        t += 1
        time.sleep(10)

@app.route('/')
def dashboard():
    """The HTML/JS interface for the Sensor Hub."""
    return render_template_string("""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>GlucoNav | Sensor Hub v1.5</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
        <style>
            :root { --accent: #38bdf8; --bg: #0f172a; --card: #1e293b; }
            body { font-family: 'Inter', sans-serif; background: var(--bg); color: white; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
            .container { background: var(--card); padding: 40px; border-radius: 32px; width: 90%; max-width: 800px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); border: 1px solid rgba(255,255,255,0.1); }
            .badge { display: inline-block; padding: 6px 12px; background: rgba(56, 189, 248, 0.1); color: var(--accent); border-radius: 100px; font-weight: 600; font-size: 12px; margin-bottom: 20px; border: 1px solid var(--accent); }
            h1 { font-weight: 800; margin: 0 0 40px 0; font-size: 20px; text-transform: uppercase; letter-spacing: 1px; color: #fff; }
            .hero { display: flex; align-items: flex-end; justify-content: space-between; margin-bottom: 40px; }
            .glucose-readout { display: flex; align-items: baseline; }
            .value { font-size: 96px; font-weight: 800; line-height: 0.8; letter-spacing: -3px; color: var(--accent); }
            .unit { font-size: 24px; color: #94a3b8; margin-left: 8px; font-weight: 400; }
            .pairing-card { background: rgba(0,0,0,0.2); padding: 20px; border-radius: 20px; text-align: right; }
            input { background: #334155; border: 1px solid #475569; color: white; padding: 10px 16px; border-radius: 12px; width: 220px; font-size: 13px; margin-bottom: 10px; font-family: monospace; }
            button { background: var(--accent); color: #022c22; border: none; padding: 10px 20px; border-radius: 12px; font-weight: bold; cursor: pointer; transition: 0.2s; }
            button:hover { filter: brightness(1.1); transform: scale(1.02); }
            .chart-box { background: rgba(0,0,0,0.2); border-radius: 20px; padding: 20px; height: 200px; margin-top: 20px; }
            .footer { margin-top: 30px; font-size: 11px; color: #475569; letter-spacing: 0.5px; display: flex; justify-content: space-between; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="badge">📡 TRANSMITTING VIA NETWORK</div>
            <h1>Sensor Hub — Pairing Dashboard</h1>
            
            <div class="hero">
                <div class="glucose-readout">
                    <div class="value" id="curVal">--</div>
                    <div class="unit">mg/dL</div>
                </div>
                <div class="pairing-card">
                    <div style="color: #64748b; font-size: 12px; margin-bottom: 8px; font-weight: 600">CONNECTED USER ID</div>
                    <input id="userIdInput" type="text" value="{{ uid }}" placeholder="Paste User ID here...">
                    <br>
                    <button onclick="updateUid()">SAVE & PAIR DEVICE</button>
                    <div id="statusMsg" style="font-size: 11px; margin-top: 8px; display: none; color: #10b981">✓ Pushing data to new user</div>
                </div>
            </div>

            <div class="chart-box">
                <canvas id="liveChart"></canvas>
            </div>

            <div class="footer">
                <span>TARGET: {{ ip }}:8000</span>
                <span id="timestamp">LAST SYNC: --:--:--</span>
            </div>
        </div>

        <script>
            const ctx = document.getElementById('liveChart').getContext('2d');
            let historyData = [];

            const chart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Glucose history',
                        data: [],
                        borderColor: '#38bdf8',
                        backgroundColor: 'rgba(56, 189, 248, 0.05)',
                        fill: true,
                        tension: 0.4,
                        borderWidth: 3,
                        pointRadius: 0
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: { min: 40, max: 260, grid: { color: 'rgba(255,255,255,0.03)' }, ticks: { color: '#475569' } },
                        x: { display: false }
                    },
                    plugins: { legend: { display: false } }
                }
            });

            async function updateUid() {
                const newId = document.getElementById('userIdInput').value.trim();
                const res = await fetch('/update-uid', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({new_id: newId})
                });
                const data = await res.json();
                if(data.status === 'success') {
                    const msg = document.getElementById('statusMsg');
                    msg.style.display = 'block';
                    setTimeout(() => msg.style.display = 'none', 3000);
                }
            }

            async function refresh() {
                const res = await fetch('/data');
                const history = await res.json();
                if (history.length > 0) {
                    const last = history[history.length - 1];
                    document.getElementById('curVal').innerText = Math.round(last.value);
                    document.getElementById('timestamp').innerText = `LAST SYNC: ${last.time}`;
                    chart.data.labels = history.map(h => h.time);
                    chart.data.datasets[0].data = history.map(h => h.value);
                    chart.update('none');
                }
            }
            setInterval(refresh, 2000);
        </script>
    </body>
    </html>
    """, ip=SERVER_IP, uid=USER_ID)

@app.route('/update-uid', methods=['POST'])
def change_uid():
    global USER_ID
    data = request.get_json()
    if 'new_id' in data:
        USER_ID = data['new_id']
        print(f"🔄 Sensor paired with new user: {USER_ID}")
        return jsonify({"status": "success", "user_id": USER_ID})
    return jsonify({"status": "error"}), 400

@app.route('/data')
def get_data():
    return jsonify(glucose_history)

if __name__ == "__main__":
    threading.Thread(target=background_simulator, daemon=True).start()
    print("🌍 CGM Sensor Hub (Web) UI starting at http://localhost:5000")
    app.run(host="0.0.0.0", port=5000, debug=False)
