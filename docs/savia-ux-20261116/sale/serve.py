from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
server=ThreadingHTTPServer(('127.0.0.1',0),SimpleHTTPRequestHandler)
print(server.server_port,flush=True)
server.serve_forever()
