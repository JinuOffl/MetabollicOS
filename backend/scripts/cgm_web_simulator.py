import flask
from flask import Flask, render_template_string, request, jsonify
import requests
import threading
import time
import random
import math

# --- CONFIGURATION ---
SERVER_IP = "10.28.33.169"  # Default: same machine. Change via web UI below.
USER_ID = "demo_user_experienced"  # Default demo user

app = Flask(__name__)

# Shared state between background thread and web UI
glucose_history = []
spike_requested = False   # flag set by /spike endpoint

def background_simulator():
    """Tireless background loop to push data to the main backend."""
    global spike_requested
    t = 0
    while True:
        if spike_requested:
            # Instant spike: send 245 for the next 2 ticks, then return to normal
            val = round(240 + random.uniform(0, 15), 1)
            spike_requested = False
            print(f"⚡ SPIKE triggered! Sending {val} mg/dL to user {USER_ID}")
        else:
            # Normal sine-wave glucose curve (80–200 mg/dL)
            base = 140 + (60 * math.sin(t / 20))
            val = round(base + random.uniform(-4, 4), 1)
            val = max(70, min(200, val))

        entry = {"time": time.strftime("%H:%M:%S"), "value": val}
        glucose_history.append(entry)

        # Keep last 30 readings for the chart
        if len(glucose_history) > 30:
            glucose_history.pop(0)

        # Push to Main Backend
        api_url = f"http://{SERVER_IP}:8000/api/v1/glucose-reading"
        payload = {"user_id": USER_ID, "glucose_mgdl": val}

        try:
            requests.post(api_url, json=payload, timeout=2)
        except Exception:
            pass  # Keep simulator alive even if backend is down

        t += 1
        time.sleep(10)


HTML_TEMPLATE = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>GlucoNav | CGM Sensor Hub</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
        <style>
            :root {
                --accent: #38bdf8;
                --accent-glow: rgba(56, 189, 248, 0.3);
                --danger: #f43f5e;
                --danger-glow: rgba(244, 63, 94, 0.35);
                --success: #10b981;
                --bg: #0a0f1e;
                --card: #111827;
                --card2: #1e293b;
                --border: rgba(255,255,255,0.07);
                --text: #f1f5f9;
                --muted: #64748b;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: 'Inter', sans-serif;
                background: var(--bg);
                color: var(--text);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 24px;
                background-image: radial-gradient(ellipse at 20% 50%, rgba(56,189,248,0.04) 0%, transparent 60%),
                                  radial-gradient(ellipse at 80% 20%, rgba(168,85,247,0.04) 0%, transparent 50%);
            }
            .container {
                background: var(--card);
                border-radius: 28px;
                width: 100%;
                max-width: 880px;
                border: 1px solid var(--border);
                overflow: hidden;
                box-shadow: 0 40px 80px rgba(0,0,0,0.6);
            }
            /* Top bar */
            .topbar {
                background: rgba(255,255,255,0.02);
                border-bottom: 1px solid var(--border);
                padding: 18px 28px;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }
            .logo { display: flex; align-items: center; gap: 12px; }
            .logo-dot {
                width: 10px; height: 10px;
                background: var(--success);
                border-radius: 50%;
                box-shadow: 0 0 8px var(--success);
                animation: pulse 2s infinite;
            }
            @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }
            .logo-text { font-weight: 800; font-size: 15px; letter-spacing: 0.5px; }
            .logo-sub { font-size: 11px; color: var(--muted); }
            .status-pill {
                background: rgba(16,185,129,0.1);
                border: 1px solid rgba(16,185,129,0.3);
                color: var(--success);
                padding: 5px 14px;
                border-radius: 100px;
                font-size: 11px;
                font-weight: 600;
            }

            /* Main content */
            .main { padding: 32px 28px; }

            /* Hero row */
            .hero-row {
                display: grid;
                grid-template-columns: 1fr auto;
                gap: 24px;
                align-items: start;
                margin-bottom: 28px;
            }
            .readout-box { }
            .readout-label { font-size: 11px; color: var(--muted); font-weight: 600; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 8px; }
            .readout-value {
                font-size: 80px;
                font-weight: 800;
                line-height: 1;
                letter-spacing: -3px;
                color: var(--accent);
                text-shadow: 0 0 40px var(--accent-glow);
                transition: color 0.5s, text-shadow 0.5s;
            }
            .readout-value.danger { color: var(--danger); text-shadow: 0 0 40px var(--danger-glow); }
            .readout-unit { font-size: 20px; color: var(--muted); font-weight: 400; margin-top: 4px; }
            .readout-range { font-size: 12px; color: var(--muted); margin-top: 8px; }
            .target { color: var(--success); font-weight: 600; }
            
            /* Pairing card */
            .pair-card {
                background: var(--card2);
                border: 1px solid var(--border);
                border-radius: 20px;
                padding: 20px;
                min-width: 260px;
            }
            .pair-label { font-size: 11px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 10px; }
            .pair-input {
                background: rgba(255,255,255,0.05);
                border: 1px solid var(--border);
                color: white;
                padding: 10px 14px;
                border-radius: 10px;
                width: 100%;
                font-size: 12px;
                font-family: 'Courier New', monospace;
                margin-bottom: 10px;
                outline: none;
            }
            .pair-input:focus { border-color: var(--accent); }
            .btn-pair {
                background: linear-gradient(135deg, var(--accent), #6366f1);
                color: white;
                border: none;
                padding: 10px 18px;
                border-radius: 10px;
                font-weight: 700;
                font-size: 12px;
                cursor: pointer;
                width: 100%;
                transition: opacity 0.2s, transform 0.1s;
            }
            .btn-pair:hover { opacity: 0.9; transform: translateY(-1px); }
            .pair-status { font-size: 11px; color: var(--success); margin-top: 8px; display: none; text-align: center; }

            /* ⚡ SPIKE BUTTON — the star of the show */
            .spike-section {
                margin-bottom: 28px;
                display: flex;
                gap: 16px;
                align-items: center;
            }
            .btn-spike {
                flex: 1;
                background: linear-gradient(135deg, var(--danger), #f97316);
                color: white;
                border: none;
                padding: 18px 28px;
                border-radius: 16px;
                font-weight: 800;
                font-size: 16px;
                cursor: pointer;
                letter-spacing: 0.5px;
                transition: all 0.2s;
                box-shadow: 0 8px 24px var(--danger-glow);
                position: relative;
                overflow: hidden;
            }
            .btn-spike:hover { transform: translateY(-2px); box-shadow: 0 12px 32px var(--danger-glow); }
            .btn-spike:active { transform: translateY(0); }
            .btn-spike::before {
                content: '';
                position: absolute;
                top: 0; left: -100%;
                width: 60%; height: 100%;
                background: rgba(255,255,255,0.15);
                transform: skewX(-20deg);
                transition: left 0.4s;
            }
            .btn-spike:hover::before { left: 150%; }
            .btn-normalize {
                background: rgba(16,185,129,0.1);
                color: var(--success);
                border: 1px solid rgba(16,185,129,0.3);
                padding: 18px 24px;
                border-radius: 16px;
                font-weight: 700;
                font-size: 14px;
                cursor: pointer;
                transition: all 0.2s;
            }
            .btn-normalize:hover { background: rgba(16,185,129,0.2); }
            .spike-badge {
                display: none;
                background: var(--danger);
                color: white;
                padding: 6px 14px;
                border-radius: 100px;
                font-size: 12px;
                font-weight: 700;
                animation: blink 0.8s infinite;
            }
            @keyframes blink { 0%,100%{opacity:1} 50%{opacity:0} }

            /* Chart */
            .chart-card {
                background: var(--card2);
                border: 1px solid var(--border);
                border-radius: 20px;
                padding: 20px 20px 12px;
                margin-bottom: 20px;
            }
            .chart-title { font-size: 12px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 14px; }
            .chart-wrap { height: 160px; }

            /* Footer */
            .footer { display: flex; justify-content: space-between; font-size: 11px; color: var(--muted); padding-top: 4px; }
        </style>
    </head>
    <body>
        <div class="container">
            <!-- Top bar -->
            <div class="topbar">
                <div class="logo">
                    <div class="logo-dot"></div>
                    <div>
                        <div class="logo-text">GlucoNav CGM Sensor Hub</div>
                        <div class="logo-sub">Continuous Glucose Monitoring Device</div>
                    </div>
                </div>
                <div class="status-pill" id="connStatus">● LIVE</div>
            </div>

            <!-- Main content -->
            <div class="main">
                <!-- Config Card -->
                <div class="card" style="margin-bottom: 24px;">
                  <h3 style="margin:0 0 12px; font-size:14px; color:var(--muted);">⚙️ BACKEND CONFIG</h3>
                  <div style="display:flex; gap:12px; flex-wrap:wrap;">
                    <input id="cfgIp" type="text" value="{{ server_ip }}" placeholder="localhost"
                      style="flex:2; padding:8px 12px; background:#0a0f1e; border:1px solid var(--border); border-radius:8px; color:var(--text); font-family:Inter;">
                    <input id="cfgUser" type="text" value="{{ user_id }}" placeholder="demo_user_experienced"
                      style="flex:3; padding:8px 12px; background:#0a0f1e; border:1px solid var(--border); border-radius:8px; color:var(--text); font-family:Inter;">
                    <button onclick="saveConfig()" 
                      style="padding:8px 20px; background:var(--accent); border:none; border-radius:8px; color:#0a0f1e; font-weight:700; cursor:pointer;">
                      Apply
                    </button>
                  </div>
                  <p id="cfgStatus" style="margin:8px 0 0; font-size:12px; color:var(--muted);"></p>
                </div>

                <!-- Hero row: glucose reading + pairing -->
                <div class="hero-row">
                    <div class="readout-box">
                        <div class="readout-label">Current Glucose</div>
                        <div class="readout-value" id="curVal">--</div>
                        <div class="readout-unit">mg/dL</div>
                        <div class="readout-range">
                            Target: <span class="target">70–140 mg/dL</span>
                        </div>
                    </div>
                    <div class="pair-card">
                        <div class="pair-label">Paired User ID</div>
                        <input class="pair-input" id="userIdInput" type="text" value="{{ user_id }}" placeholder="Paste Device Pairing ID...">
                        <button class="btn-pair" onclick="updateUid()">⚡ Pair This Device</button>
                        <div class="pair-status" id="pairStatus">✓ Device paired and pushing data</div>
                    </div>
                </div>

                <!-- ⚡ SPIKE TRIGGER BUTTONS -->
                <div class="spike-section">
                    <button class="btn-spike" id="spikeBtn" onclick="triggerSpike()">
                        ⚡ TRIGGER GLUCOSE SPIKE — 245 mg/dL
                    </button>
                    <button class="btn-normalize" onclick="triggerNormal()">
                        ✓ Normalize
                    </button>
                    <div class="spike-badge" id="spikeBadge">SPIKING</div>
                </div>

                <!-- Live chart -->
                <div class="chart-card">
                    <div class="chart-title">📈 Glucose History (last 30 readings)</div>
                    <div class="chart-wrap">
                        <canvas id="liveChart"></canvas>
                    </div>
                </div>

                <!-- Footer -->
                <div class="footer">
                    <span>TARGET BACKEND: 10.240.206.169:8000</span>
                    <span id="timestamp">LAST SYNC: --:--:--</span>
                </div>
            </div>
        </div>

        <script>
            async function saveConfig() {
              const ip = document.getElementById('cfgIp').value.trim();
              const uid = document.getElementById('cfgUser').value.trim();
              const res = await fetch('/config', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({server_ip: ip, user_id: uid})
              });
              const data = await res.json();
              document.getElementById('cfgStatus').textContent = 
                `✅ Now pushing to http://${data.server_ip}:8000 as ${data.user_id}`;
            }

            const ctx = document.getElementById('liveChart').getContext('2d');
            const DANGER_THRESHOLD = 200;

            const chart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Glucose mg/dL',
                        data: [],
                        borderColor: '#38bdf8',
                        backgroundColor: 'rgba(56, 189, 248, 0.06)',
                        fill: true,
                        tension: 0.4,
                        borderWidth: 2.5,
                        pointRadius: 0,
                        pointHoverRadius: 4,
                    }, {
                        // Danger threshold line at 180 mg/dL
                        label: 'High threshold (180)',
                        data: [],
                        borderColor: 'rgba(244, 63, 94, 0.4)',
                        borderWidth: 1,
                        borderDash: [6, 4],
                        pointRadius: 0,
                        fill: false,
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    animation: { duration: 300 },
                    scales: {
                        y: {
                            min: 50, max: 280,
                            grid: { color: 'rgba(255,255,255,0.03)' },
                            ticks: { color: '#475569', font: { size: 11 } }
                        },
                        x: { display: false }
                    },
                    plugins: { legend: { display: false } }
                }
            });

            async function refresh() {
                try {
                    const res = await fetch('/data');
                    const history = await res.json();
                    if (history.length === 0) return;

                    const last = history[history.length - 1];
                    const val = Math.round(last.value);
                    const isHigh = val > DANGER_THRESHOLD;

                    document.getElementById('curVal').innerText = val;
                    document.getElementById('curVal').className = 'readout-value' + (isHigh ? ' danger' : '');
                    document.getElementById('timestamp').innerText = `LAST SYNC: ${last.time}`;

                    const labels = history.map(h => h.time);
                    chart.data.labels = labels;
                    chart.data.datasets[0].data = history.map(h => h.value);
                    chart.data.datasets[0].borderColor = isHigh ? '#f43f5e' : '#38bdf8';
                    chart.data.datasets[0].backgroundColor = isHigh ? 'rgba(244,63,94,0.06)' : 'rgba(56,189,248,0.06)';
                    // Threshold line
                    chart.data.datasets[1].data = labels.map(() => 180);
                    chart.update('none');
                } catch(e) {
                    document.getElementById('connStatus').textContent = '● RECONNECTING';
                }
            }

            async function triggerSpike() {
                const btn = document.getElementById('spikeBtn');
                const badge = document.getElementById('spikeBadge');
                btn.disabled = true;
                btn.textContent = '📡 Spike signal sent...';
                badge.style.display = 'inline-block';
                
                await fetch('/spike', { method: 'POST' });
                
                setTimeout(() => {
                    btn.disabled = false;
                    btn.textContent = '⚡ TRIGGER GLUCOSE SPIKE — 245 mg/dL';
                    badge.style.display = 'none';
                }, 12000);
            }

            async function triggerNormal() {
                await fetch('/normalize', { method: 'POST' });
            }

            async function updateUid() {
                const newId = document.getElementById('userIdInput').value.trim();
                if (!newId) return;
                const res = await fetch('/update-uid', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({new_id: newId})
                });
                const data = await res.json();
                if (data.status === 'success') {
                    const msg = document.getElementById('pairStatus');
                    msg.style.display = 'block';
                    setTimeout(() => msg.style.display = 'none', 4000);
                }
            }

            // Refresh every 3 seconds for snappy UI
            setInterval(refresh, 3000);
            refresh();
        </script>
    </body>
    </html>
"""

@app.route('/')
def dashboard():
    """The HTML/JS interface for the Sensor Hub."""
    return render_template_string(HTML_TEMPLATE, server_ip=SERVER_IP, user_id=USER_ID)

@app.route('/config', methods=['POST'])
def set_config():
    global SERVER_IP, USER_ID
    data = request.json
    if 'server_ip' in data:
        SERVER_IP = data['server_ip']
    if 'user_id' in data:
        USER_ID = data['user_id']
    return jsonify({"server_ip": SERVER_IP, "user_id": USER_ID, "status": "updated"})

@app.route('/config', methods=['GET'])
def get_config():
    return jsonify({"server_ip": SERVER_IP, "user_id": USER_ID})


@app.route('/spike', methods=['POST'])
def trigger_spike():
    """Force the next reading to be a high glucose value (simulates meal spike)."""
    global spike_requested, glucose_history, USER_ID
    spike_requested = True

    # Also push immediately to backend so Flutter sees it without waiting 10s
    spk = round(240 + random.uniform(0, 15), 1)
    entry = {"time": time.strftime("%H:%M:%S"), "value": spk}
    glucose_history.append(entry)
    if len(glucose_history) > 30: glucose_history.pop(0)

    api_url = f"http://{SERVER_IP}:8000/api/v1/glucose-reading"
    try:
        requests.post(api_url, json={"user_id": USER_ID, "glucose_mgdl": spk}, timeout=3)
        print(f"⚡ INSTANT SPIKE: {spk} mg/dL → user {USER_ID}")
    except Exception as e:
        print(f"⚠️  Spike push failed: {e}")
    return jsonify({"status": "spike_triggered", "value": spk})


@app.route('/normalize', methods=['POST'])
def trigger_normal():
    """Push a normal glucose reading immediately."""
    global USER_ID
    val = round(110 + random.uniform(-5, 10), 1)
    entry = {"time": time.strftime("%H:%M:%S"), "value": val}
    glucose_history.append(entry)
    if len(glucose_history) > 30: glucose_history.pop(0)

    api_url = f"http://{SERVER_IP}:8000/api/v1/glucose-reading"
    try:
        requests.post(api_url, json={"user_id": USER_ID, "glucose_mgdl": val}, timeout=3)
        print(f"✅ NORMALIZED: {val} mg/dL → user {USER_ID}")
    except Exception as e:
        print(f"⚠️  Normalize push failed: {e}")
    return jsonify({"status": "normalized", "value": val})


@app.route('/update-uid', methods=['POST'])
def change_uid():
    global USER_ID
    data = request.get_json()
    if 'new_id' in data and data['new_id']:
        USER_ID = data['new_id'].strip()
        print(f"🔄 Sensor paired with new user: {USER_ID}")
        return jsonify({"status": "success", "user_id": USER_ID})
    return jsonify({"status": "error"}), 400


@app.route('/data')
def get_data():
    return jsonify(glucose_history)


if __name__ == "__main__":
    threading.Thread(target=background_simulator, daemon=True).start()
    print("=" * 55)
    print("  🌡️  GlucoNav CGM Sensor Hub")
    print(f"  🌍  UI: http://10.240.206.169:5000")
    print(f"  📡  Pushing to Backend: http://{SERVER_IP}:8000")
    print(f"  ⚡  POST /spike    — trigger 245 mg/dL spike")
    print(f"  ✅  POST /normalize — normalize glucose")
    print("=" * 55)
    app.run(host="0.0.0.0", port=5000, debug=False)
