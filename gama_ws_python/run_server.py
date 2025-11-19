import os
from uvicorn import Config, Server
from app import app

LAN_IP = "10.230.219.32" 
PORT   = 8040         

# ภายในเครื่องให้ uvicorn ฟังทุก interface ไปเลย
HOST = "0.0.0.0"

if __name__ == "__main__":
    print("\n🚀 Server is running!")
    print("🌐 Open this link on any device in the same Wi-Fi:")
    print(f"👉 http://{LAN_IP}:{PORT}")
    print(f"💻 Local: http://localhost:{PORT}\n")

    config = Config(
        app=app,
        host=HOST,
        port=PORT,
        log_level=os.getenv("LOG_LEVEL", "info"),
    )
    Server(config).run()