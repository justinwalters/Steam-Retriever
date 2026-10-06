#!/usr/bin/env python3
"""Mock of the Steam Retriever HTTP API (see CONTRACT.md on the bridge branch).

Lets the tvOS app be built before the real server on the mini exists.
Stdlib only.  Run:  python3 mock_server.py [--port 48080] [--token dev]
Covers come from ../../Art if a game has no image in ./covers.
"""
import argparse, json, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
GAMES = json.loads((HERE / "games.json").read_text())
LAUNCH_SECONDS = 4  # how long "starting" lasts before "playing"

state = {"steamEnv": None, "launching": None, "playing": None, "sunshine": True, "since": time.time()}
lock = threading.Lock()


def find(gid):
    return next((g for g in GAMES if g["id"] == gid), None)


def finish_launch(gid):
    time.sleep(LAUNCH_SECONDS)
    with lock:
        if state["launching"] == gid:
            state.update(launching=None, playing=gid, since=time.time())


class Handler(BaseHTTPRequestHandler):
    token = "dev"

    def send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authed(self):
        if self.headers.get("X-Retriever-Token") == self.token:
            return True
        self.send_json(401, {"ok": False, "error": "bad token"})
        return False

    def do_GET(self):
        if not self.authed():
            return
        parts = self.path.split("?")[0].strip("/").split("/")
        if parts == ["api", "games"]:
            with lock:
                playing = state["playing"]
            return self.send_json(200, [{**g, "running": g["id"] == playing} for g in GAMES])
        if parts == ["api", "status"]:
            with lock:
                s = dict(state)
            idle = 0 if (s["launching"] or s["playing"]) else int(time.time() - s["since"])
            return self.send_json(200, {k: s[k] for k in ("steamEnv", "launching", "playing", "sunshine")} | {"idleSeconds": idle})
        if len(parts) == 4 and parts[:2] == ["api", "games"] and parts[3] == "cover":
            g = find(parts[2])
            if not g:
                return self.send_json(404, {"ok": False, "error": "unknown game"})
            img = HERE / "covers" / f"{g['id']}.jpg"
            if not img.exists():
                img = HERE.parent.parent / "Art" / "backdrop.jpg"
            data = img.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            return self.wfile.write(data)
        self.send_json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if not self.authed():
            return
        parts = self.path.strip("/").split("/")
        if len(parts) == 3 and parts[:2] == ["api", "launch"]:
            g = find(parts[2])
            if not g:
                return self.send_json(404, {"ok": False, "error": "unknown game"})
            with lock:
                state.update(steamEnv=g["env"], launching=g["id"], playing=None)
            threading.Thread(target=finish_launch, args=(g["id"],), daemon=True).start()
            return self.send_json(200, {"ok": True, "state": "starting"})
        self.send_json(404, {"ok": False, "error": "not found"})

    def log_message(self, fmt, *args):
        print("mock:", fmt % args)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=48080)
    ap.add_argument("--token", default="dev")
    a = ap.parse_args()
    Handler.token = a.token
    print(f"Mock Steam Retriever API on http://0.0.0.0:{a.port}  (token: {a.token})")
    ThreadingHTTPServer(("0.0.0.0", a.port), Handler).serve_forever()
