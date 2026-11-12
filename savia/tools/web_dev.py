#!/usr/bin/env python3
"""Dev only: serve savia/web/ and proxy /api/ and /health to a local SAVIA API, same origin.

Loopback only. Not for the pilot: the API will host savia/web/ itself.

  python savia/tools/web_dev.py [--port 5090] [--api http://127.0.0.1:5080]
"""
import argparse
import http.server
import urllib.error
import urllib.request
from pathlib import Path

WEB = Path(__file__).resolve().parents[1] / "web"
HOP = {"connection", "keep-alive", "transfer-encoding", "te", "trailer", "upgrade",
       "proxy-authorization", "proxy-authenticate", "host", "content-length"}


def make_handler(api):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(WEB), **k)

        extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                          ".mjs": "text/javascript", ".js": "text/javascript"}

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            super().end_headers()

        def _proxied(self):
            return self.path.startswith("/api/") or self.path == "/health"

        def _proxy(self):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None
            request = urllib.request.Request(api + self.path, data=body, method=self.command)
            for name, value in self.headers.items():
                if name.lower() not in HOP:
                    request.add_header(name, value)
            try:
                response = urllib.request.urlopen(request, timeout=60)
            except urllib.error.HTTPError as error:
                response = error
            except OSError as error:
                payload = (f'{{"code":"dev.api_unreachable","message":"La API local no responde: {type(error).__name__}.",'
                           f'"traceId":null}}').encode()
                self.send_response(502)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                return
            data = response.read()
            self.send_response(response.status if hasattr(response, "status") else response.code)
            for name, value in response.headers.items():
                if name.lower() not in HOP:
                    self.send_header(name, value)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            self._proxy() if self._proxied() else super().do_GET()

        def do_POST(self):
            self._proxy() if self._proxied() else self.send_error(405)

        def log_message(self, fmt, *args):
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5090)
    parser.add_argument("--api", default="http://127.0.0.1:5080")
    args = parser.parse_args()
    if not args.api.startswith(("http://127.0.0.1:", "http://localhost:")):
        raise SystemExit("Refused: --api must be a loopback URL.")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(args.api.rstrip("/")))
    print(f"web_dev: http://127.0.0.1:{args.port}/ -> {WEB}; /api -> {args.api}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
