#!/usr/bin/env python3
"""Offline deployment safeguards; no Cloudflare API calls."""
import importlib.util
import json
import io
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, HTTPSHandler, build_opener
from urllib.response import addinfourl
from email.message import Message

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('deployment', ROOT / 'tools/deployment.py')
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)
SHA = 'a' * 40


class DeploymentTests(unittest.TestCase):
    def test_artifact_integrity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'index.html').write_text('demo')
            (root / deploy.MARKER).write_text(json.dumps({'sha': SHA, 'files': deploy.inventory(root)}))
            deploy.verify(root, SHA)
            with self.assertRaises(ValueError):
                deploy.verify(root, 'b' * 40)
            (root / 'index.html').write_text('changed')
            with self.assertRaises(ValueError):
                deploy.verify(root, SHA)

    def test_extra_file_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / deploy.MARKER).write_text(json.dumps({'sha': SHA, 'files': {}}))
            (root / 'unexpected.txt').write_text('extra')
            with self.assertRaises(ValueError):
                deploy.verify(root, SHA)

    def test_original_and_unrelated_urls_rejected_before_network(self):
        for url in ('https://martha-silva-demo.example.workers.dev', 'http://martha-silva-preview.example.workers.dev',
                    'https://example.com', 'https://martha-silva-preview.example.workers.dev.evil.test'):
            with self.subTest(url=url), self.assertRaises(ValueError):
                deploy.smoke(Path('does-not-exist'), SHA, url)

    def test_access_denial_not_retried(self):
        for status in (401, 403):
            with patch.object(deploy, 'verify', return_value={'files': {}}), \
                 patch.object(deploy, 'build_opener') as factory, \
                 patch.object(deploy.time, 'sleep') as sleep:
                request = factory.return_value.open
                request.side_effect = HTTPError('url', status, 'denied', {}, None)
                with self.assertRaises(HTTPError):
                    deploy.smoke(Path('.'), SHA, 'https://martha-silva-preview.example.workers.dev')
                self.assertEqual(request.call_count, 1)
                sleep.assert_not_called()

    def test_nested_marker_is_in_inventory_and_tampering_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'nested').mkdir()
            nested = root / 'nested' / deploy.MARKER
            nested.write_text('nested content')
            files = deploy.inventory(root)
            self.assertIn('nested/deployment.json', files)
            (root / deploy.MARKER).write_text(json.dumps({'sha': SHA, 'files': files}))
            deploy.verify(root, SHA)
            nested.write_text('tampered')
            with self.assertRaises(ValueError):
                deploy.verify(root, SHA)
            nested.unlink()
            with self.assertRaises(ValueError):
                deploy.verify(root, SHA)
            (root / deploy.MARKER).write_text(json.dumps({'sha': SHA, 'files': {}}))
            nested.write_text('unexpected nested marker')
            with self.assertRaises(ValueError):
                deploy.verify(root, SHA)

    def test_symlinks_rejected_including_marker_and_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / 'real'
            target.write_text('data')
            for name, destination in ((deploy.MARKER, target), ('linked-dir', root)):
                link = root / name
                try:
                    link.symlink_to(destination, target_is_directory=destination.is_dir())
                except OSError as error:
                    self.skipTest('Symlink creation unavailable: ' + str(error))
                with self.assertRaises(ValueError):
                    deploy.inventory(root)
                link.unlink()

    def test_url_preflight_cli_and_normalization(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        self.assertEqual(deploy.validate_preview_url(base + '/'), base)
        for suffix in (':443', '/index.html', '?query', '#fragment', '\n', '/\t'):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                deploy.validate_preview_url(base + suffix)
        result = subprocess.run([sys.executable, str(ROOT / 'tools/deployment.py'),
                                 'validate-url', '--url', base], capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run([sys.executable, str(ROOT / 'tools/deployment.py'),
                                 'validate-url', '--url', 'https://example.com'], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_cross_origin_redirect_rejected_before_following(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        handler = deploy.SameOriginRedirectHandler(base)
        for target in ('https://evil.test/', 'http://' + base[8:] + '/',
                       base + ':444/', 'https://user@' + base[8:] + '/'):
            with self.subTest(target=target), \
                 patch.object(deploy.HTTPRedirectHandler, 'redirect_request') as follow:
                with self.assertRaises(deploy.UnsafeRedirect):
                    handler.redirect_request(Request(base), None, 302, 'Found', {}, target)
                follow.assert_not_called()

    def test_opener_blocks_cross_origin_without_second_request(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        requested = []

        class Transport(HTTPSHandler):
            def https_open(self, request):
                requested.append(request.full_url)
                headers = Message()
                headers['Location'] = 'https://unapproved.example/target'
                response = addinfourl(io.BytesIO(b''), headers, request.full_url, 302)
                response.msg = 'Found'
                return response

        opener = build_opener(deploy.SameOriginRedirectHandler(base), Transport())
        with self.assertRaises(deploy.UnsafeRedirect):
            opener.open(base + '/deployment.json')
        self.assertEqual(requested, [base + '/deployment.json'])

    def test_opener_follows_relative_same_origin_normalization(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        requested = []

        class Transport(HTTPSHandler):
            def https_open(self, request):
                requested.append(request.full_url)
                headers = Message()
                redirect = request.full_url.endswith('/index.html')
                if redirect:
                    headers['Location'] = '/'
                response = addinfourl(io.BytesIO(b'demo'), headers, request.full_url,
                                      302 if redirect else 200)
                response.msg = 'Found' if redirect else 'OK'
                return response

        opener = build_opener(deploy.SameOriginRedirectHandler(base), Transport())
        with opener.open(base + '/index.html') as response:
            self.assertEqual(response.read(), b'demo')
        self.assertEqual(requested, [base + '/index.html', base + '/'])

    def test_same_origin_normalization_redirect_allowed(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        handler = deploy.SameOriginRedirectHandler(base)
        for target in (base + '/', base.upper().replace('HTTPS:', 'https:') + ':443/index.html'):
            request = handler.redirect_request(Request(base), None, 302, 'Found', {}, target)
            self.assertEqual(request.full_url, target)

    def test_smoke_success_and_redirect_failure_not_retried(self):
        base = 'https://martha-silva-preview.example.workers.dev'
        names = ('index.html', 'catalogo.html', 'styles.css', 'app.js', 'demo-api.js')
        data = {'sha': SHA, 'files': {name: deploy.digest(name.encode()) for name in names}}
        responses = [io.BytesIO(json.dumps(data).encode())]
        responses += [io.BytesIO(name.encode()) for name in ('index.html',) + names]
        responses += [HTTPError(base, 404, 'missing', {}, None)]
        with patch.object(deploy, 'verify', return_value=data), \
             patch.object(deploy, 'build_opener') as factory, \
             patch.object(deploy.time, 'sleep') as sleep:
            request = factory.return_value.open
            request.side_effect = responses
            deploy.smoke(Path('.'), SHA, base + '/')
            self.assertEqual(request.call_count, 8)
            self.assertTrue(all(call.args[0].startswith(base + '/') for call in request.call_args_list))
            self.assertIsInstance(factory.call_args.args[0], deploy.SameOriginRedirectHandler)
            sleep.assert_not_called()
            request.reset_mock()
            request.side_effect = deploy.UnsafeRedirect('outside origin')
            with self.assertRaises(deploy.UnsafeRedirect):
                deploy.smoke(Path('.'), SHA, base)
            self.assertEqual(request.call_count, 1)
            sleep.assert_not_called()

    def test_only_new_static_worker(self):
        config = json.loads((ROOT / 'wrangler.jsonc').read_text())
        self.assertEqual(config['name'], 'martha-silva-preview')
        self.assertEqual(config['assets'], {'directory': './dist', 'html_handling': 'auto-trailing-slash', 'not_found_handling': 'none'})
        self.assertFalse(set(config) & {'main', 'routes', 'route', 'account_id', 'kv_namespaces', 'd1_databases'})
        package = json.loads((ROOT / 'package.json').read_text())
        self.assertEqual(package['devDependencies']['wrangler'], '4.152.0')

    def test_workflow_gates_and_same_sha(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        job = workflow.split('\n  deploy:\n')[1]
        for guard in ("needs: [check, artifact]", "github.event_name != 'pull_request'", "github.ref == 'refs/heads/main'",
                      "vars.CLOUDFLARE_DEPLOY_ENABLED == 'true'", 'secrets.CLOUDFLARE_PREVIEW_API_TOKEN',
                      'name: recovered-demo-${{ github.sha }}', 'ref: ${{ github.sha }}',
                      "if: steps.credentials.outputs.ready == 'true'", 'contents: read', 'cancel-in-progress: false'):
            self.assertIn(guard, job)
        preflight = job.index('python tools/deployment.py validate-url')
        self.assertLess(preflight, job.index('secrets.CLOUDFLARE_PREVIEW_API_TOKEN'))
        self.assertLess(preflight, job.index('npm run deploy:preview'))
        self.assertNotIn('contents: write', workflow)
        self.assertNotIn('pull_request_target', workflow)


if __name__ == '__main__':
    unittest.main()
