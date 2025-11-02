import socket
import uvicorn
from app import app

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip

def find_free_port(start=8000, max_tries=50):
    for port in range(start, start + max_tries):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("0.0.0.0", port))
                return port
            except OSError:
                continue
    raise RuntimeError("No free ports found.")

if __name__ == "__main__":
    ip = get_local_ip()
    port = find_free_port(8000)
    print("\n🚀 Server is running!")
    print(f"🌐 Open this link on any device in the same Wi-Fi:")
    print(f"👉 http://{ip}:{port}\n")
    
    uvicorn.run(app, host="0.0.0.0", port=port)

