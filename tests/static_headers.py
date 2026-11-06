"""Static policy regression; --runtime exercises Wrangler on disposable assets.

No account calls or deployment. The runtime probe is deliberately separate from
the portable runner, which does not require root deployment dependencies.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
POLICY = ROOT / 'build-inputs/static/_headers'


def validate(headers, marker=False, missing=False):
    headers = {key.lower(): value for key, value in headers.items()}
    csp = headers.get('content-security-policy', '')
    for directive in ("default-src 'self'", "script-src 'self'", "object-src 'none'",
                      "base-uri 'self'", "frame-ancestors 'none'", "form-action 'self'"):
        assert directive in csp.split('; '), (directive, csp)
    assert 'unsafe-eval' not in csp
    assert headers.get('x-content-type-options') == 'nosniff'
    assert headers.get('referrer-policy') == 'strict-origin-when-cross-origin'
    assert headers.get('x-robots-tag') == 'noindex, nofollow'
    assert headers.get('access-control-allow-origin') != '*'
    cache = headers.get('cache-control', '')
    assert 'immutable' not in cache
    assert cache == ('' if missing else 'no-store' if marker else 'public, max-age=0, must-revalidate'), cache


class PolicyTests(unittest.TestCase):
    def test_single_global_policy_and_marker_only_cache_override(self):
        text = POLICY.read_text()
        paths = [line for line in text.splitlines() if line.startswith('/')]
        self.assertEqual(paths, ['/*', '/deployment.json'])
        self.assertEqual(text.count('Cache-Control:'), 1)
        self.assertNotIn('immutable', text)
        self.assertNotIn('unsafe-eval', text)
        self.assertEqual(POLICY.read_bytes(), (ROOT / 'dist/_headers').read_bytes())

    def test_fail_closed_when_policy_missing_or_weakened(self):
        with self.assertRaises(AssertionError):
            validate({})
        good = {'Content-Security-Policy': "default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'",
                'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin',
                'X-Robots-Tag': 'noindex, nofollow', 'Cache-Control': 'public, max-age=0, must-revalidate'}
        validate(good)
        for key, value in [('Content-Security-Policy', "default-src *"),
                           ('Cache-Control', 'public, max-age=31536000, immutable'),
                           ('Access-Control-Allow-Origin', '*')]:
            with self.subTest(key=key), self.assertRaises(AssertionError):
                validate(dict(good, **{key: value}))


def runtime(port, output):
    # Bind first: never attach to another worker's listener.
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', port))
    results = {'port': port, 'runs': [], 'cleanup': []}
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='storefront-headers-') as temporary:
        base = Path(temporary)
        assets = base / 'assets'
        shutil.copytree(ROOT / 'dist', assets)
        spec = importlib.util.spec_from_file_location('deployment', ROOT / 'tools/deployment.py')
        deploy = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(deploy)
        sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        (assets / deploy.MARKER).write_text(json.dumps({'sha': sha, 'files': deploy.inventory(assets)}) + '\n')
        deploy.verify(assets, sha)
        config = json.loads((ROOT / 'wrangler.jsonc').read_text())
        config['assets']['directory'] = str(assets)
        config.pop('$schema', None)
        (base / 'wrangler.json').write_text(json.dumps(config))
        (base / 'empty.env').write_text('')
        env = {k: v for k, v in os.environ.items() if not k.startswith(('CLOUDFLARE_', 'CF_'))}
        env['WRANGLER_SEND_METRICS'] = 'false'
        original = (assets / '_headers').read_bytes()
        try:
            for negative in (False, True, False):
                label = 'negative' if negative else ('restored' if results['runs'] else 'positive')
                if negative:
                    (assets / '_headers').unlink()
                else:
                    (assets / '_headers').write_bytes(original)
                command = [shutil.which('node'), str(ROOT / 'node_modules/wrangler/bin/wrangler.js'),
                           'dev', '--config', str(base / 'wrangler.json'), '--local', '--ip', '127.0.0.1',
                           '--port', str(port), '--inspector-port', '0', '--persist-to', str(base / 'state'),
                           '--env-file', str(base / 'empty.env'), '--log-level', 'error', '--no-live-reload']
                with (output / (label + '.log')).open('w') as log:
                    process = subprocess.Popen(command, cwd=base, env=env, stdout=log, stderr=subprocess.STDOUT,
                                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
                    run = {'label': label, 'pid': process.pid, 'command': command, 'responses': []}
                    results['runs'].append(run)
                    try:
                        deadline = time.monotonic() + 45
                        while True:
                            try:
                                with urlopen(f'http://127.0.0.1:{port}/', timeout=1):
                                    break
                            except (URLError, TimeoutError):
                                if process.poll() is not None or time.monotonic() > deadline:
                                    raise RuntimeError('Wrangler failed to start; inspect ' + str(output / (label + '.log')))
                                time.sleep(.25)
                        paths = ('/', '/app.js', '/styles.css', '/catalog.js', '/demo-api.js',
                                 '/integration-adapters.js', '/deployment.json', '/__missing_headers_probe__', '/_headers')
                        for path in paths:
                            try:
                                response = urlopen(f'http://127.0.0.1:{port}{path}', timeout=5)
                            except HTTPError as error:
                                response = error
                            with response:
                                body = response.read()
                                headers = dict(response.headers.items())
                                run['responses'].append({'path': path, 'status': response.status,
                                                         'headers': headers, 'sha256': hashlib.sha256(body).hexdigest()})
                                assert response.status == (404 if path in paths[-2:] else 200), path
                                if path not in paths[-2:]:
                                    expected = assets / (path.lstrip('/') or 'index.html')
                                    assert body == expected.read_bytes(), path
                                if negative:
                                    try:
                                        validate(headers, path == '/deployment.json', path in paths[-2:])
                                    except AssertionError:
                                        pass
                                    else:
                                        raise AssertionError('Missing policy was accepted: ' + path)
                                else:
                                    validate(headers, path == '/deployment.json', path in paths[-2:])
                    finally:
                        if os.name == 'nt':
                            killed = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'], capture_output=True)
                            results['cleanup'].append({'pid': process.pid, 'taskkill_exit': killed.returncode})
                        else:
                            process.terminate()
                            results['cleanup'].append({'pid': process.pid})
                        process.wait(timeout=15)
                        results['cleanup'][-1]['process_exited'] = process.poll() is not None
        finally:
            (assets / '_headers').write_bytes(original)
            (output / 'runtime.json').write_text(json.dumps(results, indent=2) + '\n')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', port))
    print('PASS: Wrangler positive / removed-policy negative / restored; exact HTTP bytes, headers, 404s; owned process trees closed; port released')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', action='store_true')
    parser.add_argument('--port', type=int, default=18091)
    parser.add_argument('--output', type=Path)
    args, rest = parser.parse_known_args()
    if args.runtime:
        if not args.output:
            parser.error('--output outside the repository is required for runtime logs')
        runtime(args.port, args.output)
    else:
        unittest.main(argv=[__file__] + rest)
