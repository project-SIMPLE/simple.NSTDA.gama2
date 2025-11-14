import os
import socket
from uvicorn import Config, Server
from app import app


def get_local_ip() -> str:
    """หา IP ภายในเครือข่าย LAN อย่างรวดเร็ว + มี fallback ที่ปลอดภัย"""
    # วิธีหลัก: ใช้ UDP connect (ไม่ต้องมีการส่งจริง) + ตั้ง timeout สั้น ๆ
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.settimeout(0.3)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass
    finally:
        try:
            s.close()
        except Exception:
            pass

    # วิธีสำรอง: ใช้ hostname
    try:
        ip = socket.gethostbyname(socket.gethostname())
        if ip and not ip.startswith("127."):
            return ip
    except Exception:
        pass

    # สุดท้ายจริง ๆ
    return "127.0.0.1"


def prebound_socket(host: str, port: int | None):
    """
    ผูก (bind) socket ล่วงหน้าเพื่อลด race condition
    - ถ้า port None/0 จะให้ OS สุ่มพอร์ตให้
    - ถ้าผูกพอร์ตไม่สำเร็จ (เช่นซ้ำ) จะ fallback เป็นพอร์ตสุ่ม
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # ช่วยให้ restart ได้ไวขึ้นบนบางระบบ
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except OSError:
            pass

    try:
        sock.bind((host, 0 if not port else port))
    except OSError:
        # ถ้า port ที่ระบุถูกใช้อยู่ ให้สุ่มพอร์ตแทน
        sock.bind((host, 0))

    sock.listen(512)
    real_port = sock.getsockname()[1]
    return sock, real_port


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    env_port = os.getenv("PORT")
    port = int(env_port) if env_port else None

    sock, real_port = prebound_socket(host, port)
    lan_ip = get_local_ip()

    print("\n🚀 Server is running!")
    print("🌐 Open this link on any device in the same Wi-Fi:")
    print(f"👉 http://{lan_ip}:{real_port}")
    print(f"💻 Local: http://localhost:{real_port}\n")

    config = Config(app=app, log_level=os.getenv("LOG_LEVEL", "info"))
    Server(config).run(sockets=[sock])