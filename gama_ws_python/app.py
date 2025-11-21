from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
import os, json, socket, asyncio
from typing import Dict, Set, List, Optional
import websockets
from datetime import datetime

# ---------- config ----------
HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", "8000"))
BASE_DIR   = os.path.dirname(__file__)
STATIC_DIR = os.path.join(BASE_DIR, "static")

COINS_FILE         = os.path.join(BASE_DIR, "coins.json")
INITIAL_COINS_FILE = os.path.join(BASE_DIR, "initial_coins.json")
SCORES_FILE        = os.path.join(BASE_DIR, "scores.json")        # species (10 ค่า) ต่อทีม
STACK_TREES_FILE   = os.path.join(BASE_DIR, "stack_trees.json")   # 6x3 ต่อทีม
TREE_GROWTH_FILE   = os.path.join(BASE_DIR, "tree_growth.json")   # 3 ค่า ต่อทีม
TEAM_SCORES_FILE   = os.path.join(BASE_DIR, "team_scores.json")   # 2 ค่า ต่อทีม: [total, current]

LOG_FILE   = os.path.join(BASE_DIR, "gama_actions.csv")

TEAMS = ["Blue","Red","Green","Yellow","Black","White"]

RESET_ON_START         = os.environ.get("RESET_COINS_ON_START", "1") != "0"
RESET_SCORES_ON_START  = os.environ.get("RESET_SCORES_ON_START", "1") != "0"

GAMA_HOST = os.environ.get("GAMA_IP_ADDRESS", "localhost")
GAMA_PORT = int(os.environ.get("GAMA_WS_PORT", "3001"))

# ปรับค่า keepalive ของ websockets ให้ทนเน็ตแกว่ง ๆ มากขึ้น
WS_CONNECT_KW = dict(ping_interval=20, ping_timeout=20, max_queue=64, open_timeout=4)

app = FastAPI()
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


# ---------- helpers ----------
def atomic_write_json(path: str, obj):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)

def _zeros10() -> List[int]:
    return [0] * 10

def _norm10_int_0_10(values: List) -> List[int]:
    """Make sure list length = 10, each int in [0,10]."""
    out: List[int] = []
    for x in list(values)[:10]:
        try:
            v = int(round(float(x)))
        except Exception:
            v = 0
        v = max(0, min(10, v))
        out.append(v)
    if len(out) < 10:
        out += [0] * (10 - len(out))
    return out

def _zero_stack() -> List[List[int]]:
    """6 rounds x 3 states = 6x3"""
    return [[0, 0, 0] for _ in range(6)]

def _norm_stack(values) -> List[List[int]]:
    """normalize เป็น 6x3 จำนวนเต็ม >= 0"""
    rows: List[List[int]] = []
    vals = values if isinstance(values, list) else []
    for i in range(6):
        row = vals[i] if (i < len(vals) and isinstance(vals[i], list)) else []
        norm_row: List[int] = []
        for j in range(3):
            try:
                v = int(round(float(row[j]))) if j < len(row) else 0
            except Exception:
                v = 0
            if v < 0:
                v = 0
            norm_row.append(v)
        rows.append(norm_row)
    return rows

def _zero_growth() -> List[int]:
    """3 ค่า (เช่น Stage 1/2/3)"""
    return [0, 0, 0]

def _norm_growth(values) -> List[int]:
    vals = values if isinstance(values, list) else []
    out: List[int] = []
    for i in range(3):
        try:
            v = int(round(float(vals[i]))) if i < len(vals) else 0
        except Exception:
            v = 0
        if v < 0:
            v = 0
        out.append(v)
    return out

def _zero_team_scores() -> Dict[str, List[int]]:
    """ให้แต่ละทีมเก็บ [total_score, current_score]"""
    return {t: [0, 0] for t in TEAMS}


# ---------- coins state with simple JSON persistence ----------
def load_coins() -> Dict[str, int]:
    if os.path.exists(COINS_FILE):
        try:
            with open(COINS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            # รองรับทั้ง dict แบบเก่า (team -> int) และแบบใหม่ (team -> {"coins":x})
            if all(isinstance(v, dict) for v in data.values()):
                # ถ้าบังเอิญเก็บแบบซับซ้อนมาก่อน จะดึง field "coins"
                return {t: int(max(0, data.get(t, {}).get("coins", 0))) for t in TEAMS}
            else:
                return {t: int(max(0, data.get(t, 0))) for t in TEAMS}
        except Exception:
            pass
    return {t: 0 for t in TEAMS}

def save_coins(state: Dict[str, int]):
    atomic_write_json(COINS_FILE, state)

def load_initial_coins() -> Dict[str, int]:
    if os.path.exists(INITIAL_COINS_FILE):
        try:
            with open(INITIAL_COINS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            return {t: int(max(0, data.get(t, 0))) for t in TEAMS}
        except Exception:
            pass
    # ถ้าไม่มีไฟล์ initial_coins ให้ fallback = coins ปัจจุบัน
    coins_now = load_coins()
    return {t: int(max(0, coins_now.get(t, 0))) for t in TEAMS}

def save_initial_coins(state: Dict[str, int]):
    atomic_write_json(INITIAL_COINS_FILE, state)

COINS: Dict[str, int] = load_coins()
INITIAL_COINS: Dict[str, int] = load_initial_coins()


# ---------- species scores (10 ค่า) ----------
def load_scores() -> Dict[str, List[int]]:
    if os.path.exists(SCORES_FILE):
        try:
            with open(SCORES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            out = {}
            for t in TEAMS:
                arr = data.get(t, [])
                out[t] = _norm10_int_0_10(arr)
            return out
        except Exception:
            pass
    return {t: _zeros10() for t in TEAMS}

def save_scores(state: Dict[str, List[int]]):
    atomic_write_json(SCORES_FILE, state)

SCORES: Dict[str, List[int]] = load_scores()


# ---------- stack trees (6x3) ----------
def load_stack_trees() -> Dict[str, List[List[int]]]:
    if os.path.exists(STACK_TREES_FILE):
        try:
            with open(STACK_TREES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            out = {}
            for t in TEAMS:
                arr = data.get(t, _zero_stack())
                out[t] = _norm_stack(arr)
            return out
        except Exception:
            pass
    return {t: _zero_stack() for t in TEAMS}

def save_stack_trees(state: Dict[str, List[List[int]]]):
    atomic_write_json(STACK_TREES_FILE, state)

STACK_TREES: Dict[str, List[List[int]]] = load_stack_trees()


# ---------- tree growth stage (3 ค่า) ----------
def load_tree_growth() -> Dict[str, List[int]]:
    if os.path.exists(TREE_GROWTH_FILE):
        try:
            with open(TREE_GROWTH_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            out = {}
            for t in TEAMS:
                arr = data.get(t, _zero_growth())
                out[t] = _norm_growth(arr)
            return out
        except Exception:
            pass
    return {t: _zero_growth() for t in TEAMS}

def save_tree_growth(state: Dict[str, List[int]]):
    atomic_write_json(TREE_GROWTH_FILE, state)

TREE_GROWTH: Dict[str, List[int]] = load_tree_growth()


# ---------- team scores (2 ค่า ต่อทีม: [total, current]) ----------
def load_team_scores() -> Dict[str, List[int]]:
    """
    รองรับทั้งไฟล์เก่า (ค่าเดียวต่อทีม) และไฟล์ใหม่ ([total, current])
    """
    if os.path.exists(TEAM_SCORES_FILE):
        try:
            with open(TEAM_SCORES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            out: Dict[str, List[int]] = {}
            for t in TEAMS:
                val = data.get(t, 0)
                if isinstance(val, list) and len(val) >= 2:
                    try:
                        total = int(max(0, float(val[0])))
                    except Exception:
                        total = 0
                    try:
                        current = int(max(0, float(val[1])))
                    except Exception:
                        current = total
                else:
                    try:
                        v = int(max(0, float(val)))
                    except Exception:
                        v = 0
                    total = v
                    current = v
                out[t] = [total, current]
            return out
        except Exception:
            pass
    return _zero_team_scores()

def save_team_scores(state: Dict[str, List[int]]):
    atomic_write_json(TEAM_SCORES_FILE, state)

TEAM_SCORES: Dict[str, List[int]] = load_team_scores()


# ---------- locks ----------
team_locks   = {t: asyncio.Lock() for t in TEAMS}   # coins per team
coins_lock   = asyncio.Lock()
scores_locks = {t: asyncio.Lock() for t in TEAMS}   # species scores per team
stack_locks  = {t: asyncio.Lock() for t in TEAMS}   # stack trees per team
growth_locks = {t: asyncio.Lock() for t in TEAMS}   # growth stage per team
team_scores_lock = asyncio.Lock()


# ---------- browser WS pool (for broadcast) ----------
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

async def broadcast_scores_update(team: str):
    await _broadcast({"type": "score_update", "team": team, "score": SCORES.get(team, _zeros10())})

async def broadcast_stack_tree_update(team: str):
    await _broadcast({"type": "stack_tree_update", "team": team, "score": STACK_TREES.get(team, _zero_stack())})

async def broadcast_tree_growth_update(team: str):
    await _broadcast({"type": "tree_growth_stage_update", "team": team, "score": TREE_GROWTH.get(team, _zero_growth())})

async def broadcast_team_scores_update():
    # ส่งเป็น list ของ [total, current] ตามลำดับ TEAMS
    scores_list = [[TEAM_SCORES[t][0], TEAM_SCORES[t][1]] for t in TEAMS]
    await _broadcast({"type": "team_score_update", "team": "", "teams": TEAMS, "score": scores_list})


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
    global COINS, INITIAL_COINS, SCORES, STACK_TREES, TREE_GROWTH, TEAM_SCORES
    init_log_file()

    if RESET_ON_START:
        COINS = {t: 0 for t in TEAMS}
        INITIAL_COINS = {t: 0 for t in TEAMS}
        save_coins(COINS)
        save_initial_coins(INITIAL_COINS)
        print("💾 Reset all coins & initial coins to 0 at server startup")
    else:
        print("↩️  Skipped coins reset on startup (RESET_COINS_ON_START=0)")

    if RESET_SCORES_ON_START:
        SCORES = {t: _zeros10() for t in TEAMS}
        save_scores(SCORES)
        STACK_TREES = {t: _zero_stack() for t in TEAMS}
        save_stack_trees(STACK_TREES)
        TREE_GROWTH = {t: _zero_growth() for t in TEAMS}
        save_tree_growth(TREE_GROWTH)
        TEAM_SCORES = _zero_team_scores()
        save_team_scores(TEAM_SCORES)
        print("💾 Reset all scores / stack / growth / team scores at server startup")
    else:
        print("↩️  Skipped scores reset on startup (RESET_SCORES_ON_START=0)")


# ---------- pages ----------
@app.get("/", response_class=HTMLResponse)
def root():
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))

@app.get("/static/team.html", response_class=HTMLResponse)
def team_page():
    return FileResponse(os.path.join(STATIC_DIR, "team.html"))


# ---------- tiny health endpoint ----------
@app.get("/healthz")
def healthz():
    return {
        "ok": True,
        "teams": TEAMS,
        "coins_file": os.path.exists(COINS_FILE),
        "initial_coins_file": os.path.exists(INITIAL_COINS_FILE),
        "scores_file": os.path.exists(SCORES_FILE),
        "stack_trees_file": os.path.exists(STACK_TREES_FILE),
        "tree_growth_file": os.path.exists(TREE_GROWTH_FILE),
        "team_scores_file": os.path.exists(TEAM_SCORES_FILE),
        "browser_ws": len(BROWSER_SOCKETS),
    }


# ---------- coins API ----------
@app.get("/api/coins")
def api_get_all_coins():
    return COINS

@app.get("/api/coins/{team}")
def api_get_team_coins(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {
        "team": team,
        "coins": COINS.get(team, 0),
        "initial_coins": INITIAL_COINS.get(team, COINS.get(team, 0)),
    }

@app.post("/api/coins")
async def api_set_all_coins(req: Request):
    """
    ใช้ตอนหน้า index ตั้งค่า coins ของทุกทีมในรอบใหม่
    -> ตั้งทั้ง coins และ initial_coins เท่ากัน
    """
    data = await req.json()
    async with coins_lock:
        for t in TEAMS:
            val = int(max(0, data.get(t, 0)))
            COINS[t] = val
            INITIAL_COINS[t] = val
        save_coins(COINS)
        save_initial_coins(INITIAL_COINS)
    await asyncio.gather(*(broadcast_coins_update(t) for t in TEAMS))
    return {"ok": True, "coins": COINS, "initial_coins": INITIAL_COINS}

@app.post("/api/coins/set")
async def api_set_one_coin(req: Request):
    """
    ตั้งค่า coins ให้ทีมเดียว
    ตีความว่าเป็นการตั้งค่าเริ่มต้นใหม่ของทีมนั้นในรอบนี้
    -> ตั้งทั้ง coins และ initial_coins
    """
    data = await req.json()
    team = data.get("team")
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    lock = team_locks[team]
    async with lock:
        val = int(max(0, data.get("coins", 0)))
        COINS[team] = val
        INITIAL_COINS[team] = val
        save_coins(COINS)
        save_initial_coins(INITIAL_COINS)
    await broadcast_coins_update(team)
    return {
        "ok": True,
        "team": team,
        "coins": COINS[team],
        "initial_coins": INITIAL_COINS[team],
    }

@app.post("/api/coins/decrement")
async def api_decrement(req: Request):
    data = await req.json()
    team = data.get("team")
    cost = int(max(0, data.get("cost", 0)))
    action = str(data.get("action", "")).strip()

    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)

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
        return JSONResponse({"error": "unknown_team"}, status_code=400)

    lock = team_locks[team]
    async with lock:
        COINS[team] = COINS.get(team, 0) + amount
        save_coins(COINS)

    client_ip = req.client.host if req.client else "-"
    append_action_log(team, f"refund_{amount}", client_ip)

    await broadcast_coins_update(team)
    return {"ok": True, "team": team, "coins": COINS[team]}


# ---------- scores API (species 10 ค่า) ----------
@app.get("/api/scores")
def api_scores_all():
    return SCORES

@app.get("/api/scores/{team}")
def api_scores_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {"team": team, "scores": SCORES.get(team, _zeros10())}

@app.post("/api/scores/set")
async def api_scores_set(req: Request):
    data = await req.json()
    team = data.get("team")
    arr = data.get("scores", [])
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)

    nums = _norm10_int_0_10(arr)
    lock = scores_locks[team]
    async with lock:
        SCORES[team] = nums
        save_scores(SCORES)

    await broadcast_scores_update(team)
    return {"ok": True, "team": team, "scores": SCORES[team]}


# ---------- stack trees API ----------
@app.get("/api/stack_trees/{team}")
def api_stack_trees_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {"team": team, "stack": STACK_TREES.get(team, _zero_stack())}


# ---------- tree growth stage API ----------
@app.get("/api/tree_growth/{team}")
def api_tree_growth_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {"team": team, "growth": TREE_GROWTH.get(team, _zero_growth())}

# alias สำหรับ team.html → ใช้ field "score"
@app.get("/api/tree_growth_stage/{team}")
def api_tree_growth_stage_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {"team": team, "score": TREE_GROWTH.get(team, _zero_growth())}


# ---------- team scores API (leaderboard) ----------
@app.get("/api/team_scores")
def api_team_scores():
    # คืน dict: { "Blue":[total,current], ... }
    return TEAM_SCORES

@app.get("/api/team_scores/{team}")
def api_team_score_team(team: str):
    if team not in TEAMS:
        return JSONResponse({"error": "unknown_team"}, status_code=400)
    return {"team": team, "score": TEAM_SCORES.get(team, [0, 0])}


# ---------- logs download ----------
@app.get("/api/logs/actions")
def api_download_logs():
    if not os.path.exists(LOG_FILE):
        return JSONResponse({"error": "no_log"}, status_code=404)
    return FileResponse(LOG_FILE, media_type="text/csv", filename="gama_actions.csv")


# ---------- parse GAMA JSON messages ----------
def _parse_gama_json(msg: str) -> Optional[dict]:
    """
    รองรับ JSON จาก GAMA เช่น:
      {"type":"score_update","team":"Blue","score":[...]}
      {"type":"stack_tree_update","team":"Blue","score":[[...],[...],...]}
      {"type":"tree_growth_stage_update","team":"Blue","score":[...]}
      {"type":"team_score_update","team":"","score":[...]}  # ตอนนี้ score อาจเป็น [total,current] ต่อทีม
    """
    try:
        o = json.loads(msg)
    except Exception:
        return None
    if not isinstance(o, dict):
        return None
    return o


async def _ingest_score_update(team: str, arr: List):
    nums = _norm10_int_0_10(arr)
    lock = scores_locks[team]
    async with lock:
        SCORES[team] = nums
        save_scores(SCORES)
    await broadcast_scores_update(team)

async def _ingest_stack_tree_update(team: str, arr):
    norm = _norm_stack(arr)
    lock = stack_locks[team]
    async with lock:
        STACK_TREES[team] = norm
        save_stack_trees(STACK_TREES)
    await broadcast_stack_tree_update(team)

async def _ingest_tree_growth_update(team: str, arr):
    norm = _norm_growth(arr)
    lock = growth_locks[team]
    async with lock:
        TREE_GROWTH[team] = norm
        save_tree_growth(TREE_GROWTH)
    await broadcast_tree_growth_update(team)

async def _ingest_team_score_update(arr):
    """
    arr เป็น list ตามลำดับ TEAMS:
      แบบใหม่: [[total,current], [total,current], ...]
      แบบเก่า: [score_blue, score_red, ...]
    """
    vals = arr if isinstance(arr, list) else []
    async with team_scores_lock:
        for i, t in enumerate(TEAMS):
            if i < len(vals):
                entry = vals[i]
                if isinstance(entry, (list, tuple)) and len(entry) >= 1:
                    try:
                        total = int(max(0, float(entry[0])))
                    except Exception:
                        total = 0
                    if len(entry) >= 2:
                        try:
                            current = int(max(0, float(entry[1])))
                        except Exception:
                            current = total
                    else:
                        current = total
                else:
                    try:
                        v = int(max(0, float(entry)))
                    except Exception:
                        v = 0
                    total = v
                    current = v
                TEAM_SCORES[t] = [total, current]
            else:
                TEAM_SCORES[t] = [0, 0]
        save_team_scores(TEAM_SCORES)
    await broadcast_team_scores_update()


# ---------- WebSocket (bridge) ----------
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
            gama_ws = await websockets.connect(f"ws://{GAMA_HOST}:{GAMA_PORT}", **WS_CONNECT_KW)
            await websocket.send_json({"info": "gama_connected"})
        except Exception:
            gama_ws = None
            await websocket.send_json({"error": "gama_unreachable"})

    async def connect_loop():
        # พยายามเชื่อม GAMA ใหม่เรื่อย ๆ จนกว่าจะสำเร็จหรือถูกยกเลิก
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

                # parse JSON จาก GAMA
                obj = _parse_gama_json(msg)

                if obj is not None:
                    typ  = str(obj.get("type", "")).strip()
                    team = obj.get("team", "") or ""
                    score = obj.get("score", None)
                    # เผื่อมีคนส่ง "scores"
                    if score is None:
                        score = obj.get("scores", None)

                    # 1) species score (10 ค่า ต่อทีม)
                    if typ in ("score_update", "scores_update") and team in TEAMS and isinstance(score, list):
                        await _ingest_score_update(team, score)

                    # 2) stack trees (6x3 ต่อทีม)
                    elif typ == "stack_tree_update" and team in TEAMS:
                        await _ingest_stack_tree_update(team, score)

                    # 3) tree growth stage (3 ค่า ต่อทีม)
                    elif typ == "tree_growth_stage_update" and team in TEAMS:
                        await _ingest_tree_growth_update(team, score)

                    # 4) team score (leaderboard) → ไม่ใช้ team
                    elif typ == "team_score_update" and isinstance(score, list):
                        await _ingest_team_score_update(score)

                # ส่งต่อข้อความดิบกลับให้ client ปัจจุบัน (เผื่อ frontend อยากใช้เอง)
                await websocket.send_text(msg)

            except Exception:
                await websocket.send_json({"error": "gama_unreachable"})
                try:
                    await gama_ws.close()
                except Exception:
                    pass
                gama_ws = None
                # ปล่อยให้ connect_loop กลับไปลองเชื่อมใหม่

    connect_task = asyncio.create_task(connect_loop())
    b2g_task     = asyncio.create_task(browser_to_gama())
    g2b_task     = asyncio.create_task(gama_to_browser())

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
            BROWSER_SOCKETS.discard(websocket)


# ---------- util (only used when run directly) ----------
def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.settimeout(0.3)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

if __name__ == "__main__":
    import uvicorn
    ip = get_lan_ip()
    print("🚀 Server is running!")
    print("🌐 Open this link on any device in the same Wi-Fi:")
    print(f"👉 http://{ip}:{PORT}")
    uvicorn.run(app, host=HOST, port=PORT)