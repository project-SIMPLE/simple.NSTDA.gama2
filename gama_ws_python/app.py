# app.py
import json, asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import websockets

GAMA_HOST = "localhost"
GAMA_PORT = 3001
GAMA_URI  = f"ws://{GAMA_HOST}:{GAMA_PORT}"

app = FastAPI()

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def root_page():
    return FileResponse("static/index.html")

@app.websocket("/ws")
async def browser_ws(ws: WebSocket):
    await ws.accept()
    try:
        async with websockets.connect(GAMA_URI) as gama:
            # await gama.send("HELLO from bridge")

            async def pump_browser_to_gama():
                while True:
                    data = await ws.receive_text()
                    await gama.send(data)

            async def pump_gama_to_browser():
                while True:
                    msg = await gama.recv()
                    if isinstance(msg, bytes):
                        msg = msg.decode("utf-8", "ignore")
                    await ws.send_text(str(msg))

            await asyncio.gather(pump_browser_to_gama(), pump_gama_to_browser())

    except WebSocketDisconnect:
        return
    except Exception as e:
        try: await ws.send_text(json.dumps({"error": str(e)}))
        except: pass
        await ws.close()