"""Serve the built storefront with the /* headers from its own _headers file (CSP etc.)."""
import functools, http.server, sys
from pathlib import Path

ROOT = Path(sys.argv[1]); PORT = int(sys.argv[2])
headers, block = [], None
for line in (ROOT / '_headers').read_text(encoding='utf-8').splitlines():
    if not line.strip() or line.startswith('#'):
        continue
    if not line[0].isspace():
        block = line.strip()
    elif block == '/*' and ':' in line:
        k, v = line.strip().split(':', 1); headers.append((k.strip(), v.strip()))


class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        for k, v in headers:
            self.send_header(k, v)
        super().end_headers()

    def log_message(self, *a):
        pass


print('headers', [k for k, _ in headers], flush=True)
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), functools.partial(H, directory=str(ROOT))).serve_forever()
