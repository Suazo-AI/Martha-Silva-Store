#!/usr/bin/env python3
"""Offline deployment safeguards; no Cloudflare API calls."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

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
                 patch.object(deploy, 'urlopen', side_effect=HTTPError('url', status, 'denied', {}, None)) as request, \
                 patch.object(deploy.time, 'sleep') as sleep:
                with self.assertRaises(HTTPError):
                    deploy.smoke(Path('.'), SHA, 'https://martha-silva-preview.example.workers.dev')
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
        self.assertNotIn('contents: write', workflow)
        self.assertNotIn('pull_request_target', workflow)


if __name__ == '__main__':
    unittest.main()
