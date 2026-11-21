"""Loopback browser harness; applies exact repository security headers, not Cloudflare emulation."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
policy=[]
for line in (ROOT/'build-inputs/static/_headers').read_text().splitlines():
    if line.startswith('  ') and not line.strip().startswith('Cache-Control:'):
        policy.append(line.strip().split(': ',1))
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs): super().__init__(*args,directory=str(ROOT/'dist'),**kwargs)
    def end_headers(self):
        for key,value in policy: self.send_header(key,value)
        super().end_headers()
ThreadingHTTPServer(('127.0.0.1',18313),Handler).serve_forever()
