import os
from uvicorn import Config, Server
from app import app

LAN_IP = "192.168.68.51" 
PORT   = 8040         

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