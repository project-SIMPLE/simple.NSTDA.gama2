from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
import uvicorn, os, json, socket, asyncio
from typing import Dict
import websockets 
from datetime import datetime

# ---------- config ----------
HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", "8000"))
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
COINS_FILE = os.path.join(os.path.dirname(__file__), "coins.json")
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

def save_coins(state: Dict[str, int]):
    with open(COINS_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

COINS = load_coins()

# ---------- per-team async locks (prevent double-spend) ----------
team_locks = {t: asyncio.Lock() for t in TEAMS}  # NEW

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
    global COINS
    init_log_file()
    if RESET_ON_START:
        COINS = {t: 0 for t in TEAMS}
        save_coins(COINS)
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
    for t in TEAMS:
        COINS[t] = int(max(0, data.get(t, 0)))
    save_coins(COINS)
    return {"ok": True, "coins": COINS}

@app.post("/api/coins/set")
async def api_set_one(req: Request):
    data = await req.json()
    team = data.get("team")
    if team not in TEAMS:
        return JSONResponse({"error":"unknown_team"}, status_code=400)
    COINS[team] = int(max(0, data.get("coins", 0)))
    save_coins(COINS)
    return {"ok": True, "team": team, "coins": COINS[team]}

@app.post("/api/coins/decrement")
async def api_decrement(req: Request):
    # CHANGED: ทำให้ตัดเหรียญแบบอะตอมมิกด้วย per-team lock และตรวจยอดก่อนตัด
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
            # ไม่พอ -> ไม่ตัด และส่งยอดจริงกลับ
            return {"ok": False, "error": "insufficient_coins", "team": team, "coins": current}
        COINS[team] = current - cost
        save_coins(COINS)

    client_ip = req.client.host if req.client else "-"
    append_action_log(team, action or f"decrement_{cost}", client_ip)

    return {"ok": True, "team": team, "coins": COINS[team]}

@app.post("/api/coins/refund")
async def api_refund(req: Request):
    # NEW: endpoint คืนเหรียญ กรณีตัดสำเร็จแล้วส่งไป GAMA ไม่สำเร็จ
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

    return {"ok": True, "team": team, "coins": COINS[team]}

@app.get("/api/logs/actions")
def api_download_logs():
    if not os.path.exists(LOG_FILE):
        return JSONResponse({"error":"no_log"}, status_code=404)
    return FileResponse(LOG_FILE, media_type="text/csv", filename="gama_actions.csv")

# ---------- WebSocket ----------
@app.websocket("/ws")
async def ws_bridge(websocket: WebSocket):
    await websocket.accept()

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