from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
import uvicorn, os, json, socket, asyncio, re
from typing import Dict, Set, List
import websockets
from datetime import datetime

# ---------- config ----------
HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", "8000"))
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
COINS_FILE = os.path.join(os.path.dirname(__file__), "coins.json")
SCORES_FILE = os.path.join(os.path.dirname(__file__), "scores.json")   # NEW
TEAMS = ["Blue","Red","Green","Yellow","Black","White"]

RESET_ON_START = os.environ.get("RESET_COINS_ON_START", "1") != "0"

GAMA_HOST = os.environ.get("GAMA_IP_ADDRESS", "localhost")
GAMA_PORT = int(os.environ.get("GAMA_WS_PORT", "3001"))

LOG_FILE = os.path.join(os.path.dirname(__file__), "gama_actions.csv")

app = FastAPI()
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

# ---------- coins state with simple JSON persistence ----------
def load_coins() -> Dict[str, int]:
    if os.path.exists(COINS_FILE):
        try:
            with open(COINS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            return {t: int(max(0, data.get(t, 0))) for t in TEAMS}
        except Exception:
            pass
    return {t: 0 for t in TEAMS}

def atomic_write_json(path: str, obj: dict):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)

def save_coins(state: Dict[str, int]):
    atomic_write_json(COINS_FILE, state)

COINS = load_coins()

# ---------- scores state with JSON persistence (NEW) ----------
def _zeros10() -> List[int]:
    return [0]*10

def load_scores() -> Dict[str, List[int]]:
    if os.path.exists(SCORES_FILE):
        try:
            with open(SCORES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            out = {}
            for t in TEAMS:
                arr = data.get(t, [])
                # เก็บแค่ตัวเลข 10 ตัว (ถ้าน้อยกว่าเติม 0; มากกว่าตัด)
                nums = []
                for x in arr:
                    try:
                        n = int(x)
                    except Exception:
                        try:
                            n = int(float(x))
                        except Exception:
                            n = 0
                    nums.append(n)
                if len(nums) < 10:
                    nums += [0]*(10-len(nums))
                elif len(nums) > 10:
                    nums = nums[:10]
                out[t] = nums
            return out
        except Exception:
            pass
    return {t: _zeros10() for t in TEAMS}

def save_scores(state: Dict[str, List[int]]):
    atomic_write_json(SCORES_FILE, state)

SCORES = load_scores()

# ---------- per-team & global locks ----------
team_locks = {t: asyncio.Lock() for t in TEAMS}   # coins lock per team
coins_lock = asyncio.Lock()
scores_locks = {t: asyncio.Lock() for t in TEAMS} # scores lock per team  (NEW)

# ---------- browser WS pool (for broadcast coins/score updates) ----------
BROWSER_SOCKETS: Set[WebSocket] = set()
BROWSER_SOCKETS_LOCK = asyncio.Lock()

async def _broadcast(payload: dict):
    async with BROWSER_SOCKETS_LOCK:
        dead = []
        for ws in list(BROWSER_SOCKETS):
            try:
                await ws.send_json(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            BROWSER_SOCKETS.discard(ws)

async def broadcast_coins_update(team: str):
    await _broadcast({"type": "coins_update", "team": team, "coins": COINS.get(team, 0)})

async def broadcast_score_update(team: str):  # NEW
    await _broadcast({"type": "score_update", "team": team, "scores": SCORES.get(team, _zeros10())})

# ---------- simple CSV logger for actions ----------
def init_log_file():
    if not os.path.exists(LOG_FILE):
        with open(LOG_FILE, "w", encoding="utf-8") as f:
            f.write("date,time,team,action,client_ip\n")

def append_action_log(team: str, action: str, client_ip: str = "-"):
    now = datetime.now()
    date_str = now.strftime("%d/%m/%Y")
    time_str = now.strftime("%H:%M:%S")
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(f"{date_str},{time_str},{team},{action},{client_ip}\n")

# ---------- reset to zero on startup ----------
@app.on_event("startup")
async def reset_on_startup():
    global COINS, SCORES
    init_log_file()
    if RESET_ON_START:
        COINS = {t: 0 for t in TEAMS}
        save_coins(COINS)
        # คะแนนไม่รีเซ็ตตาม flag coins (คงไว้) แต่ถ้าอยากรีเซ็ตให้ uncomment สองบรรทัดล่าง
        # SCORES = {t: _zeros10() for t in TEAMS}
        # save_scores(SCORES)
        print("💾 Reset all coins to 0 at server startup")
    else:
        print("↩️  Skipped reset on startup (RESET_COINS_ON_START=0)")

# ---------- pages ----------
@app.get("/", response_class=HTMLResponse)
def root():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))

@app.get("/static/team.html", response_class=HTMLResponse)
def team_page():
    return FileResponse(os.path.join(STATIC_DIR, "team.html"))

# ---------- coins API ----------
@app.get("/api/coins")
def api_get_all():
    return COINS

@app.get("/api/coins/{team}")
def api_get_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)
    return {"team": team, "coins": COINS.get(team, 0)}

@app.post("/api/coins")
async def api_set_all(req: Request):
    data = await req.json()
    async with coins_lock:
        for t in TEAMS:
            COINS[t] = int(max(0, data.get(t, 0)))
        save_coins(COINS)
    await asyncio.gather(*(broadcast_coins_update(t) for t in TEAMS))
    return {"ok": True, "coins": COINS}

@app.post("/api/coins/set")
async def api_set_one(req: Request):
    data = await req.json()
    team = data.get("team")
    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)
    lock = team_locks[team]
    async with lock:
        COINS[team] = int(max(0, data.get("coins", 0)))
        save_coins(COINS)
    await broadcast_coins_update(team)
    return {"ok": True, "team": team, "coins": COINS[team]}

@app.post("/api/coins/decrement")
async def api_decrement(req: Request):
    data = await req.json()
    team = data.get("team")
    cost = int(max(0, data.get("cost", 0)))
    action = str(data.get("action", "")).strip()

    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)

    lock = team_locks[team]
    async with lock:
        current = COINS.get(team, 0)
        if current < cost:
            return {"ok": False, "error": "insufficient_coins", "team": team, "coins": current}
        COINS[team] = current - cost
        save_coins(COINS)

    client_ip = req.client.host if req.client else "-"
    append_action_log(team, action or f"decrement_{cost}", client_ip)

    await broadcast_coins_update(team)
    return {"ok": True, "team": team, "coins": COINS[team]}

@app.post("/api/coins/refund")
async def api_refund(req: Request):
    data = await req.json()
    team = data.get("team")
    amount = int(max(0, data.get("amount", 0)))

    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)

    lock = team_locks[team]
    async with lock:
        COINS[team] = COINS.get(team, 0) + amount
        save_coins(COINS)

    client_ip = req.client.host if req.client else "-"
    append_action_log(team, f"refund_{amount}", client_ip)

    await broadcast_coins_update(team)
    return {"ok": True, "team": team, "coins": COINS[team]}

# ---------- scores API (NEW) ----------
@app.get("/api/scores")
def api_scores_all():
    return SCORES

@app.get("/api/scores/{team}")
def api_scores_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)
    return {"team": team, "scores": SCORES.get(team, _zeros10())}

@app.post("/api/scores/set")
async def api_scores_set(req: Request):
    data = await req.json()
    team = data.get("team")
    arr = data.get("scores", [])
    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)
    # ทำให้เป็นลิสต์ยาว 10 ของตัวเลข int
    nums: List[int] = []
    for x in arr:
        try:
            n = int(x)
        except Exception:
            try:
                n = int(float(x))
            except Exception:
                n = 0
        nums.append(n)
    if len(nums) < 10:
        nums += [0]*(10-len(nums))
    elif len(nums) > 10:
        nums = nums[:10]

    lock = scores_locks[team]
    async with lock:
        SCORES[team] = nums
        save_scores(SCORES)

    await broadcast_score_update(team)
    return {"ok": True, "team": team, "scores": SCORES[team]}

@app.get("/api/logs/actions")
def api_download_logs():
    if not os.path.exists(LOG_FILE):
        return JSONResponse({"error":"no_log"}, status_code=404)
    return FileResponse(LOG_FILE, media_type="text/csv", filename="gama_actions.csv")

# ---------- helpers to parse GAMA messages (NEW) ----------
def _try_parse_json_score(msg: str):
    try:
        o = json.loads(msg)
    except Exception:
        return None
    if isinstance(o, dict) and o.get("type") == "score_update":
        team = o.get("team")
        arr = o.get("scores")
        if team in TEAMS and isinstance(arr, list):
            return team, arr
    return None

_kv_re = re.compile(r'team\s*=\s*([A-Za-z]+).*?scores?\s*=\s*\[([^\]]*)\]', re.I | re.S)

def _try_parse_kv_score(msg: str):
    m = _kv_re.search(msg or "")
    if not m:
        return None
    team = m.group(1)
    if team not in TEAMS:
        return None
    raw = m.group(2)
    arr = []
    for tok in raw.split(","):
        tok = tok.strip()
        if not tok:
            continue
        try:
            n = int(tok)
        except Exception:
            try:
                n = int(float(tok))
            except Exception:
                n = 0
        arr.append(n)
    return team, arr

async def _ingest_score_update(team: str, arr: List[int]):
    # ปรับให้ยาว 10
    nums = list(arr)
    if len(nums) < 10:
        nums += [0]*(10-len(nums))
    elif len(nums) > 10:
        nums = nums[:10]

    lock = scores_locks[team]
    async with lock:
        SCORES[team] = nums
        save_scores(SCORES)
    await broadcast_score_update(team)

# ---------- WebSocket ----------
@app.websocket("/ws")
async def ws_bridge(websocket: WebSocket):
    await websocket.accept()

    # ลงทะเบียน browser เพื่อ broadcast
    async with BROWSER_SOCKETS_LOCK:
        BROWSER_SOCKETS.add(websocket)

    gama_ws = None
    stop = False

    async def connect_once():
        nonlocal gama_ws
        try:
            gama_ws = await websockets.connect(f"ws://{GAMA_HOST}:{GAMA_PORT}")
            await websocket.send_json({"info": "gama_connected"})
        except Exception:
            gama_ws = None
            await websocket.send_json({"error": "gama_unreachable"})

    async def connect_loop():
        while not stop:
            if gama_ws is None:
                await connect_once()
                if gama_ws is None:
                    await asyncio.sleep(2.0)
                    continue
            await asyncio.sleep(0.5)

    async def browser_to_gama():
        nonlocal gama_ws
        while not stop:
            msg = await websocket.receive_text()
            if gama_ws is not None:
                try:
                    await gama_ws.send(msg)
                except Exception:
                    await websocket.send_json({"error": "gama_unreachable"})
                    try:
                        await gama_ws.close()
                    except Exception:
                        pass
                    gama_ws = None
            else:
                await websocket.send_json({"error": "gama_unreachable"})

    async def gama_to_browser():
        nonlocal gama_ws
        while not stop:
            if gama_ws is None:
                await asyncio.sleep(0.2)
                continue
            try:
                msg = await gama_ws.recv()
                if isinstance(msg, bytes):
                    msg = msg.decode("utf-8", "ignore")

                # --- NEW: ดัก score_update เข้ามา เก็บ/บันทึก/บรอดแคสต์ ---
                parsed = _try_parse_json_score(msg) or _try_parse_kv_score(msg)
                if parsed:
                    team, arr = parsed
                    await _ingest_score_update(team, arr)
                # -----------------------------------------------------------

                # ยังส่งต่อข้อความเดิมให้ browser ด้วย (เผื่อมี client พาร์สเอง)
                await websocket.send_text(msg)

            except Exception:
                await websocket.send_json({"error": "gama_unreachable"})
                try:
                    await gama_ws.close()
                except Exception:
                    pass
                gama_ws = None

    connect_task = asyncio.create_task(connect_loop())
    b2g_task = asyncio.create_task(browser_to_gama())
    g2b_task = asyncio.create_task(gama_to_browser())

    try:
        done, pending = await asyncio.wait(
            {connect_task, b2g_task, g2b_task},
            return_when=asyncio.FIRST_EXCEPTION,
        )
        for d in done:
            exc = d.exception()
            if exc:
                raise exc
    except WebSocketDisconnect:
        pass
    finally:
        stop = True
        for t in (connect_task, b2g_task, g2b_task):
            t.cancel()
        if gama_ws is not None:
            try:
                await gama_ws.close()
            except Exception:
                pass
        # ถอนทะเบียน browser
        async with BROWSER_SOCKETS_LOCK:
            if websocket in BROWSER_SOCKETS:
                BROWSER_SOCKETS.remove(websocket)

# ---------- util ----------
def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

if __name__ == "__main__":
    ip = get_lan_ip()
    print("🚀 Server is running!")
    print("🌐 Open this link on any device in the same Wi-Fi:")
    print(f"👉 http://{ip}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT)