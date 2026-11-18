"""Dependency-free failing gates for CI strategy selection and release evidence."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'ci_strategy.py'
spec = importlib.util.spec_from_file_location('ci_strategy', SCRIPT)
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class PlanTests(unittest.TestCase):
    def test_docs_only_is_fast_and_never_release_ready(self):
        p = ci.classify(['docs/architecture.md'])
        self.assertEqual(p['risk'], 'docs')
        self.assertFalse(p['run_storefront'])
        self.assertFalse(p['requires_full'])
        self.assertFalse(p['release_allowed'])

    def test_frontend_selects_adapter_tests(self):
        p = ci.classify(['src/demo-api.js', 'build-inputs/static/index.html'])
        self.assertTrue(p['run_storefront'])
        self.assertEqual(p['risk'], 'normal')

    def test_security_payments_and_db_cannot_skip_full_tests(self):
        for path in ('savia/db/migrations/V034.sql', 'backend/src/Orders.cs',
                     'src/payment.js', 'savia/web/auth.ts', '.github/workflows/ci.yml',
                     'tools/progress.py', 'docs/SECURITY.md', 'new-area/stuff.go'):
            with self.subTest(path=path):
                p = ci.classify([path])
                self.assertEqual(p['risk'], 'critical')
                self.assertTrue(p['requires_full'])

    def test_savia_web_selects_savia(self):
        self.assertTrue(ci.classify(['savia/web/tests/checkout.test.mjs'])['run_savia'])

    def test_fail_closed_on_empty_or_unsafe_path(self):
        for paths in ([], ['../secret'], ['/etc/passwd'], ['a\noutput=true'], ['bad\\name']):
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                ci.classify(paths)

    def test_deterministic_unique_paths(self):
        x = ci.classify(['src/app.js', 'src/app.js', 'docs/guide.md'])
        self.assertEqual(x['changed_paths'], ['docs/guide.md', 'src/app.js'])

    def test_static_checks_detect_invalid_python_and_json(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'bad.py').write_text('def broken(:\n')
            (root / 'bad.json').write_text('{broken')
            (root / 'good.py').write_text('x = 1\n')
            issues = ci.static_checks(root, ['bad.py', 'bad.json', 'good.py'])
            self.assertEqual(len(issues), 2)

    def test_static_checks_refuse_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'ok.py').write_text('x = 1\n')
            (root / 'link.py').symlink_to(root / 'ok.py')
            self.assertEqual(len(ci.static_checks(root, ['link.py'])), 1)

    def test_sha_inputs_checked_before_git(self):
        with self.assertRaises(ValueError):
            ci.changed_paths('branch; rm -rf', 'a' * 40)

    def test_plan_cli_reads_json_and_writes_safe_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            files = Path(directory) / 'files.json'
            output = Path(directory) / 'out'
            files.write_text(json.dumps(['savia/db/migrations/V033.sql']), encoding='utf-8')
            result = subprocess.run([sys.executable, str(SCRIPT), 'plan', '--files-json', str(files), '--output', str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['risk'], 'critical')
            self.assertIn('requires_full=true', output.read_text())


class ReleaseTests(unittest.TestCase):
    def receipt(self):
        sha = 'a' * 40
        return dict(commit_sha=sha, branch='main', artifact_sha=sha,
                    checks=[dict(name=name, head_sha=sha, status='completed', conclusion='success')
                            for name in ci.GATE3_CHECKS],
                    review_approved=True, rollback_drilled=True,
                    commercial_acceptance=True, telemetry_ready=True,
                    sql_real_verified=True, payment_sandbox_verified=True)

    def test_full_synthetic_receipt_is_structurally_eligible_but_does_not_deploy(self):
        self.assertEqual(ci.evaluate_release(self.receipt()), (True, []))

    def test_stale_duplicated_or_skipped_check_fails(self):
        for mode in ('stale', 'skip', 'duplicate', 'missing'):
            with self.subTest(mode=mode):
                r = self.receipt()
                if mode == 'stale': r['checks'][0]['head_sha'] = 'b' * 40
                if mode == 'skip': r['checks'][0]['conclusion'] = 'skipped'
                if mode == 'duplicate': r['checks'].append(dict(r['checks'][0]))
                if mode == 'missing': r['checks'].pop()
                self.assertFalse(ci.evaluate_release(r)[0])

    def test_no_business_payment_or_rollback_approval_means_no_release(self):
        for field in ('commercial_acceptance', 'payment_sandbox_verified',
                      'rollback_drilled', 'sql_real_verified', 'review_approved', 'telemetry_ready'):
            with self.subTest(field=field):
                r = self.receipt()
                r[field] = False
                self.assertFalse(ci.evaluate_release(r)[0])

    def test_missing_artifact_or_non_main_blocks(self):
        r = self.receipt()
        r['artifact_sha'] = 'b' * 40
        r['branch'] = 'Tony'
        ok, issues = ci.evaluate_release(r)
        self.assertFalse(ok)
        self.assertGreaterEqual(len(issues), 2)

    def test_release_cli_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'receipt.json'
            receipt.write_text(json.dumps({'commit_sha': 'x'}))
            result = subprocess.run([sys.executable, str(SCRIPT), 'release-check', '--receipt', str(receipt)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertFalse(json.loads(result.stdout)['eligible_for_manual_review'])


if __name__ == '__main__':
    unittest.main()
