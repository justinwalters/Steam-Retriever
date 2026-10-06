#!/usr/bin/env python3
"""Mock of the Steam Retriever API (the real one is Sources/APIServer.swift on main).

Same routes, status codes and JSON shapes, so the tvOS app can be built and run
in the simulator without the Mac mini. Python 3 stdlib only.

    python3 tvOS/mock/mock_server.py [--port 48080] [--code 123456] [--launch-seconds 8]

Pairing: POST /api/pair with the --code value (default 123456) returns a token.
The token "dev" is also always accepted, for curl.

Test-only controls (no token needed), to exercise the app's edge cases:
    curl -X POST localhost:48080/mock/sunshine/off     # "Sunshine is paused" banner
    curl -X POST localhost:48080/mock/sunshine/on
    curl -X POST localhost:48080/mock/stop             # game exits
    curl -X POST localhost:48080/mock/fail-next-launch # next launch never reaches "playing"
    curl -X POST localhost:48080/mock/reset            # forget paired tokens (forces 401)
"""
import argparse, json, secrets, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, parse_qs

HERE = Path(__file__).resolve().parent
RAW_GAMES = json.loads((HERE / "games.json").read_text())

lock = threading.Lock()
S = {
    "tokens": {"dev": "curl"},
    "pair_fails": 0,
    "steam": {"mac": False, "windows": False},
    "launching": None,
    "playing": None,
    "sunshine": True,
    "idle_since": time.time(),
    "fail_next": False,
    "meta_ready_at": time.time() + 3,   # descriptions empty for the first few seconds, like the real app
}
CFG = {"code": "123456", "launch_seconds": 8.0}


def short(desc, limit=150):
    if len(desc) <= limit:
        return desc
    cut = desc[:limit].rsplit(" ", 1)[0]
    return cut.rstrip(",.;:") + "…"


def game_dict(g):
    ready = time.time() >= S["meta_ready_at"]
    return {
        "id": g["id"], "appid": g["appid"], "name": g["name"], "env": g["env"],
        "description": g["description"] if ready else "",
        "shortDescription": short(g["description"]) if ready else "",
        "genres": g["genres"] if ready else [],
        "developer": g["developer"] if ready else "",
        "released": g["released"] if ready else "",
        "sizeBytes": g["sizeBytes"], "installedAt": g["installedAt"],
        "running": S["playing"] == g["id"],
        "starting": S["launching"] == g["id"],
    }


def find(gid):
    return next((g for g in RAW_GAMES if g["id"] == gid), None)


def finish_launch(gid, seconds, fail):
    time.sleep(seconds)
    with lock:
        if S["launching"] != gid:
            return
        if fail:
            S["launching"] = None          # gave up quietly; the app should time out / show an error
            return
        S["launching"], S["playing"] = None, gid


def steam_closes_in():
    if S["launching"] or S["playing"] or not (S["steam"]["mac"] or S["steam"]["windows"]):
        return None
    return max(0, int(300 - (time.time() - S["idle_since"])))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def send(self, code, body, ctype="application/json", cache="no-store"):
        if not isinstance(body, (bytes, bytearray)):
            body = json.dumps(body, sort_keys=True).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", cache)
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def parts(self):
        u = urlsplit(self.path)
        return [p for p in u.path.split("/") if p], {k: v[0] for k, v in parse_qs(u.query).items()}

    def authorized(self, query):
        t = self.headers.get("X-Retriever-Token") or query.get("token") or ""
        return t in S["tokens"]

    def body_json(self):
        n = int(self.headers.get("Content-Length") or 0)
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            return {}

    # ---- GET
    def do_GET(self):
        seg, q = self.parts()
        if seg[:1] != ["api"]:
            return self.send(404, {"error": "not found"})
        seg = seg[1:]
        if seg == ["ping"]:
            return self.send(200, {"app": "Steam Retriever", "api": 1})
        if not self.authorized(q):
            return self.send(401, {"error": "unauthorized"})
        with lock:
            if seg == ["games"]:
                return self.send(200, [game_dict(g) for g in RAW_GAMES])
            if seg == ["status"]:
                env = "mac" if S["steam"]["mac"] else ("windows" if S["steam"]["windows"] else None)
                return self.send(200, {
                    "steamEnv": env, "steam": dict(S["steam"]),
                    "launching": S["launching"], "playing": S["playing"],
                    "sunshine": S["sunshine"], "steamClosesInSeconds": steam_closes_in(),
                })
        if len(seg) == 3 and seg[0] == "games" and seg[2] == "cover":
            g = find(seg[1])
            if not g:
                return self.send(404, {"error": "unknown game"})
            kind = "header" if q.get("kind") == "header" else "poster"
            img = HERE / "covers" / f"{g['id']}_{kind}.jpg"
            if not img.exists():
                return self.send(404, {"error": "no cover"})
            return self.send(200, img.read_bytes(), "image/jpeg", "max-age=3600")
        self.send(404, {"error": "not found"})

    # ---- POST
    def do_POST(self):
        seg, q = self.parts()
        if seg[:1] == ["mock"]:
            return self.mock_control(seg[1:])
        if seg[:1] != ["api"]:
            return self.send(404, {"error": "not found"})
        seg = seg[1:]
        if seg == ["pair"]:
            return self.pair()
        if not self.authorized(q):
            return self.send(401, {"error": "unauthorized"})
        if len(seg) == 2 and seg[0] == "launch":
            g = find(seg[1])
            if not g:
                return self.send(404, {"error": "unknown game"})
            with lock:
                busy = S["playing"] or S["launching"]
                if busy == g["id"]:
                    return self.send(200, {"ok": True, "state": "playing" if S["playing"] else "starting"})
                if busy:
                    return self.send(409, {"ok": False, "error": f"Finish {find(busy)['name']} first."})
                switching = S["steam"]["mac" if g["env"] == "windows" else "windows"]
                S["steam"] = {"mac": g["env"] == "mac", "windows": g["env"] == "windows"}
                S["launching"], S["playing"] = g["id"], None
                fail, S["fail_next"] = S["fail_next"], False
            secs = CFG["launch_seconds"] * (2 if switching else 1)
            threading.Thread(target=finish_launch, args=(g["id"], secs, fail), daemon=True).start()
            return self.send(200, {"ok": True, "state": "starting"})
        self.send(404, {"error": "not found"})

    def pair(self):
        body = self.body_json()
        with lock:
            if S["pair_fails"] >= 5:
                return self.send(403, {"error": "no pairing in progress; choose Pair Apple TV in Steam Retriever"})
            if body.get("code") != CFG["code"]:
                S["pair_fails"] += 1
                return self.send(403, {"error": "wrong code"})
            token = secrets.token_hex(32)
            S["tokens"][token] = body.get("name") or "Apple TV"
            S["pair_fails"] = 0
        print(f"mock: paired {S['tokens'][token]}")
        return self.send(200, {"token": token})

    def mock_control(self, seg):
        with lock:
            if seg == ["sunshine", "off"]:
                S["sunshine"] = False
            elif seg == ["sunshine", "on"]:
                S["sunshine"] = True
            elif seg == ["stop"]:
                S["playing"] = S["launching"] = None
                S["idle_since"] = time.time()
            elif seg == ["fail-next-launch"]:
                S["fail_next"] = True
            elif seg == ["reset"]:
                S["tokens"] = {"dev": "curl"}
                S["pair_fails"] = 0
            else:
                return self.send(404, {"error": "unknown mock control"})
        self.send(200, {"ok": True})

    def log_message(self, fmt, *args):
        print("mock:", fmt % args)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=48080)
    ap.add_argument("--code", default="123456", help="6-digit pairing code to accept")
    ap.add_argument("--launch-seconds", type=float, default=8.0, help="time from launch to playing (doubled when Steam switches side)")
    a = ap.parse_args()
    CFG.update(code=a.code, launch_seconds=a.launch_seconds)
    print(f"Mock Steam Retriever API on http://0.0.0.0:{a.port}  pair code {a.code}  (curl token: dev)")
    ThreadingHTTPServer(("0.0.0.0", a.port), Handler).serve_forever()
