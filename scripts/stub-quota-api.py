#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import sys
from urllib.parse import urlparse


STATE = {
    "mode": "available",
    "quota_requests": 0,
}


PAYLOADS = {
    "available": {"available": True, "remaining": 123.45, "unit": "USD", "updated_at": "2026-05-09T15:30:00Z"},
    "low": {"available": True, "remaining": 1, "unit": "USD", "updated_at": "2026-05-09T15:30:00Z"},
    "unavailable": {"available": False, "remaining": 0, "unit": "USD", "updated_at": "2026-05-09T15:30:00Z"},
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/quota":
            self.handle_quota()
            return
        if path == "/stats":
            self.send_json({"mode": STATE["mode"], "quota_requests": STATE["quota_requests"]})
            return
        self.send_error(404)

    def do_POST(self):
        path = urlparse(self.path).path
        if path.startswith("/mode/"):
            mode = path.removeprefix("/mode/")
            if mode not in {"available", "low", "unavailable", "auth", "server", "invalid"}:
                self.send_error(400, "unknown mode")
                return
            STATE["mode"] = mode
            self.send_json({"mode": mode})
            return
        if path == "/stats/reset":
            STATE["quota_requests"] = 0
            self.send_json({"mode": STATE["mode"], "quota_requests": 0})
            return
        self.send_error(404)

    def handle_quota(self):
        STATE["quota_requests"] += 1
        mode = STATE["mode"]
        if mode == "auth":
            self.send_json({"error": "unauthorized"}, status=401)
        elif mode == "server":
            self.send_json({"error": "bad gateway"}, status=502)
        elif mode == "invalid":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"{invalid")
        else:
            self.send_json(PAYLOADS[mode])

    def send_json(self, payload, status=200):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        sys.stderr.write("%s - %s\n" % (self.log_date_time_string(), format % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Sub2API stub listening on http://127.0.0.1:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
