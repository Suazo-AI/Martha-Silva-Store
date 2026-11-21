"""Stdlib lifecycle/publication unit tests; no API, SQL, .NET or POSIX runtime.

Load the exact definitions with AST while omitting POSIX-only imports so these
failure cases can also run on Windows. This does not prove the POSIX harness runs
on Windows, nor replace the real Linux API/SQL smoke test.
"""
import ast
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / 'tests/golden-path/golden_path.py'
VERIFY = ROOT / 'tests/golden-path/verify_evidence.py'


def definitions():
    tree = ast.parse(HARNESS.read_text(encoding='utf-8'), filename=str(HARNESS))
    tree.body = [node for node in tree.body if not isinstance(node, ast.If)
                 and not (isinstance(node, ast.Import) and
                          any(a.name in ('fcntl', 'pty', 'termios', 'tty') for a in node.names))]
    scope = {'__file__': str(HARNESS), '__name__': 'golden_safety_unit'}
    exec(compile(tree, str(HARNESS), 'exec'), scope)
    return types.SimpleNamespace(**scope)


GP = definitions()
spec = importlib.util.spec_from_file_location('verify_golden_evidence', VERIFY)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.out = Path(self.tmp.name, 'out')
        self.env = patch.dict(os.environ, {}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def harness(self):
        args = types.SimpleNamespace(out=str(self.out), database=None, mode='smoke',
                                     no_build=True, keep_private_log=None)
        h = GP.GoldenPath(args)
        self.addCleanup(shutil.rmtree, h.private, True)
        h.database = 'SaviaInternalTest_Golden_' + 'a' * 32
        return h

    def test_secret_prevents_any_public_evidence_or_marker(self):
        h = self.harness()
        h.secrets_seen.add('synthetic-secret-value')
        h.steps = [{'step': 'synthetic-secret-value', 'status': 'FAIL'}]
        with self.assertRaises(GP.HarnessError):
            h.write_evidence('FAIL')
        self.assertFalse(any((self.out / name).exists() for name in
                             ('evidence.json', 'oracles.md', 'evidence-approved')))

    def test_constructor_removes_prior_public_files_only(self):
        self.out.mkdir()
        for name in ('evidence.json', 'oracles.md', 'evidence-approved', 'other.txt'):
            (self.out / name).write_text('previous')
        self.harness()
        self.assertEqual([p.name for p in self.out.iterdir()], ['other.txt'])

    def test_success_manifest_binds_both_exact_files(self):
        h = self.harness()
        h.write_evidence('FAIL', 'fixed diagnostic')
        marker = json.loads((self.out / 'evidence-approved').read_text())
        self.assertEqual(set(marker['files']), set(verifier.FILES))
        for name in verifier.FILES:
            self.assertEqual(marker['files'][name], hashlib.sha256((self.out / name).read_bytes()).hexdigest())
        dest = Path(self.tmp.name, 'published')
        verifier.publish(self.out, dest)
        self.assertEqual(sorted(p.name for p in dest.iterdir()), sorted(verifier.FILES))
        for name in verifier.FILES:
            self.assertEqual((dest / name).read_bytes(), (self.out / name).read_bytes())

    def test_missing_marker_never_reuses_old_published_files(self):
        self.harness()
        dest = Path(self.tmp.name, 'published')
        dest.mkdir()
        for name in verifier.FILES:
            (dest / name).write_text('stale')
        with self.assertRaises(FileNotFoundError):
            verifier.publish(self.out, dest)
        self.assertEqual(list(dest.iterdir()), [])

    def test_tampered_evidence_is_not_published(self):
        h = self.harness()
        h.write_evidence('PASS')
        (self.out / 'oracles.md').write_text('changed since scan')
        dest = Path(self.tmp.name, 'published')
        with self.assertRaises(ValueError):
            verifier.publish(self.out, dest)
        self.assertEqual(list(dest.iterdir()), [])

    def test_publication_checks_known_ci_secret_and_does_not_echo_it(self):
        h = self.harness()
        h.write_evidence('FAIL', 'synthetic-ci-secret')
        dest = Path(self.tmp.name, 'published')
        with patch.dict(os.environ, {'SQLCMDPASSWORD': 'synthetic-ci-secret'}):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = verifier.main(['--source', str(self.out), '--destination', str(dest)])
        self.assertEqual(code, 1)
        self.assertNotIn('synthetic-ci-secret', output.getvalue())
        self.assertEqual(list(dest.iterdir()), [])

    def configure_create(self, h, result):
        h.server_connection = 'synthetic-connection'
        h.build = lambda: None
        calls = []
        def helper(command, *args, **kwargs):
            calls.append(command)
            if command == 'cert':
                tls = h.private / 'tls'
                tls.mkdir()
                (tls / 'cert.pem').write_text('synthetic certificate')
                return {'ok': True}
            if command == 'create':
                if isinstance(result, BaseException):
                    raise result
                return result
            if command == 'drop':
                return {'ok': True}
            if command == 'exists':
                return {'ok': True, 'exists': False}
            raise AssertionError('Unexpected helper command')
        h.helper = helper
        return calls

    def test_interrupted_create_is_unknown_fail_and_never_drops(self):
        h = self.harness()
        calls = self.configure_create(h, GP.Stop('SIGTERM'))
        with self.assertRaises(GP.Stop):
            h.setup()
        record = h.teardown()
        self.assertIs(record['database_dropped'], False)
        self.assertEqual(record['database_creation'], 'unknown')
        self.assertTrue(record['operator_cleanup_required'])
        self.assertNotIn('drop', calls)
        self.assertTrue(record['private_dir_removed'])

    def test_refused_existing_database_is_preserved(self):
        h = self.harness()
        calls = self.configure_create(h, {'ok': False, 'detail': 'database_already_exists'})
        with self.assertRaises(GP.HarnessError):
            h.setup()
        record = h.teardown()
        self.assertEqual(record['database_creation'], 'refused')
        self.assertEqual(record['database_dropped'], 'not_created')
        self.assertNotIn('drop', calls)

    def test_no_create_reply_is_unknown_not_safe_to_drop(self):
        h = self.harness()
        calls = self.configure_create(h, {'ok': False, 'error': 'no_output', 'detail': 'exit_1'})
        with self.assertRaises(GP.HarnessError):
            h.setup()
        self.assertIs(h.teardown()['database_dropped'], False)
        self.assertNotIn('drop', calls)

    def test_pre_create_failure_is_not_created(self):
        h = self.harness()
        with self.assertRaises(GP.HarnessError):
            h.setup()
        self.assertEqual(h.teardown()['database_dropped'], 'not_created')

    def test_generic_sql_error_does_not_prove_ownership(self):
        h = self.harness()
        h.args.database = h.database  # caller-selected name might already exist
        calls = self.configure_create(h, {'ok': False, 'error': 'SqlException', 'detail': 'sql_error_1'})
        with self.assertRaises(GP.HarnessError):
            h.setup()
        record = h.teardown()
        self.assertIs(record['database_dropped'], False)
        self.assertTrue(record['operator_cleanup_required'])
        self.assertNotIn('drop', calls)

    def test_truthy_non_boolean_create_reply_is_not_ownership(self):
        h = self.harness()
        calls = self.configure_create(h, {'ok': 'true', 'pending': 0, 'applied': ['a', 'b']})
        with self.assertRaises(GP.HarnessError):
            h.setup()
        self.assertIs(h.teardown()['database_dropped'], False)
        self.assertNotIn('drop', calls)

    def test_successful_create_then_invalid_migration_count_drops_owned_database(self):
        h = self.harness()
        calls = self.configure_create(h, {'ok': True, 'pending': 1, 'applied': []})
        with self.assertRaises(GP.HarnessError):
            h.setup()
        record = h.teardown()
        self.assertIs(record['database_dropped'], True)
        self.assertEqual(calls[-2:], ['drop', 'exists'])

    def test_helper_kills_and_waits_its_own_child_on_interrupt(self):
        process = Mock()
        process.communicate.side_effect = [GP.Stop('SIGTERM'), ('', '')]
        helper = GP.Helper('synthetic-dotnet', Path('synthetic.dll'), 'synthetic-connection')
        with patch.object(GP.subprocess, 'Popen', return_value=process):
            with self.assertRaises(GP.Stop):
                helper('create', 'synthetic')
        process.kill.assert_called_once()
        self.assertEqual(process.communicate.call_count, 2)

    def test_helper_kills_and_waits_on_timeout(self):
        process = Mock()
        process.communicate.side_effect = [GP.subprocess.TimeoutExpired('synthetic', 300), ('', '')]
        helper = GP.Helper('synthetic-dotnet', Path('synthetic.dll'), 'synthetic-connection')
        with patch.object(GP.subprocess, 'Popen', return_value=process):
            with self.assertRaises(GP.subprocess.TimeoutExpired):
                helper('create', 'synthetic')
        process.kill.assert_called_once()
        self.assertEqual(process.communicate.call_count, 2)

    def test_promotion_failure_removes_partial_public_files_and_marker(self):
        h = self.harness()
        h.setup, h.smoke = Mock(), Mock()
        original_replace = os.replace
        calls = []
        def replace(source, destination):
            calls.append(str(destination))
            if len(calls) == 2:
                raise OSError('synthetic-copy-failure')
            original_replace(source, destination)
        output = io.StringIO()
        with patch.dict(GP.main.__globals__, {'GoldenPath': Mock(return_value=h)}), \
             patch.object(GP.signal, 'signal'), patch.object(GP.os, 'replace', side_effect=replace), \
             contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            code = GP.main(['--out', str(self.out), '--no-build'])
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 2)
        self.assertNotIn('synthetic-copy-failure', output.getvalue())
        for name in ('evidence.json', 'oracles.md', 'evidence-approved'):
            self.assertFalse((self.out / name).exists())

    def test_failed_scan_does_not_print_sensitive_error_or_table(self):
        h = self.harness()
        h.setup = Mock(side_effect=GP.HarnessError('synthetic-main-secret'))
        h.secrets_seen.add('synthetic-main-secret')
        out, err = io.StringIO(), io.StringIO()
        with patch.dict(GP.main.__globals__, {'GoldenPath': Mock(return_value=h)}), \
             patch.object(GP.signal, 'signal'), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = GP.main(['--out', str(self.out), '--no-build'])
        self.assertEqual(code, 1)
        self.assertNotIn('synthetic-main-secret', out.getvalue() + err.getvalue())
        self.assertFalse((self.out / 'evidence-approved').exists())


if __name__ == '__main__':
    unittest.main()
