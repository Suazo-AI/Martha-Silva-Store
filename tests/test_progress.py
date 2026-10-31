"""Real temporary Git repositories; publication transport is replaced, never used."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('progress', Path(__file__).resolve().parents[1] / 'tools/progress.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class ProgressTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.root_patch = patch.object(p, 'ROOT', self.root)
        self.root_patch.start()
        self.git('init', '-b', 'Tony')
        self.git('config', 'user.name', 'Offline fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'core.hooksPath', '.disabled-hooks')
        self.git('remote', 'add', 'origin', next(iter(p.ORIGINS)))
        self.stage('initial.txt', b'baseline\n')
        self.git('commit', '-m', 'Baseline fixture')
        self.git('update-ref', 'refs/remotes/origin/Tony', 'HEAD')

    def tearDown(self):
        self.root_patch.stop()
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True).stdout

    def stage(self, name='change.txt', data=b'working change\n'):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        self.git('add', '--', name)

    def checkpoint(self):
        self.stage()
        p.pre_commit()
        self.git('commit', '-m', 'Documented fixture')

    def test_records_staged_bytes_preserving_unstaged_work(self):
        self.stage(data=b'staged\n')
        (self.root / 'change.txt').write_bytes(b'not staged\n')
        p.pre_commit()
        receipt = next((self.root / p.RECEIPTS).glob('*.json'))
        event = json.loads(receipt.read_text())
        self.assertEqual(event['files'][0]['git_blob'], self.git('rev-parse', ':change.txt').decode().strip())
        self.assertEqual((self.root / 'change.txt').read_bytes(), b'not staged\n')
        self.git('commit', '-m', 'Only staged bytes')
        p.verify()

    def test_precommit_is_idempotent(self):
        self.stage()
        p.pre_commit()
        first = self.git('write-tree')
        p.pre_commit()
        self.assertEqual(first, self.git('write-tree'))

    def test_modified_index_rejects_stale_receipt(self):
        self.stage()
        p.pre_commit()
        self.stage(data=b'changed again\n')
        with self.assertRaises(p.Blocked):
            p.pre_commit()

    def test_tampered_receipt_rejected(self):
        self.stage()
        p.pre_commit()
        receipt = next((self.root / p.RECEIPTS).glob('*.json'))
        receipt.write_bytes(receipt.read_bytes() + b' ')
        self.git('add', '.')
        with self.assertRaises(p.Blocked):
            p.pre_commit()

    def test_sensitive_paths_and_credentials_blocked(self):
        for path in ['.env.local', 'customer-exports/data.json', 'backup.pfx', 'data.sqlite', '../escape']:
            with self.subTest(path=path), self.assertRaises(p.Blocked):
                p.scan(path, b'')
        with self.assertRaises(p.Blocked):
            p.scan('source.txt', b'gh' + b'p_' + b'x' * 36)

    def test_secret_in_index_blocks_even_if_worktree_cleaned(self):
        self.stage(data=b'gh' + b'p_' + b'x' * 36)
        (self.root / 'change.txt').write_bytes(b'clean now\n')
        with self.assertRaises(p.Blocked):
            p.pre_commit()

    def test_wrong_branch_or_remote_blocked(self):
        self.git('switch', '-c', 'other')
        with self.assertRaises(p.Blocked):
            p.guard()
        self.git('switch', 'Tony')
        self.git('remote', 'set-url', 'origin', 'https://example.invalid/wrong.git')
        with self.assertRaises(p.Blocked):
            p.guard()

    def test_missing_receipt_rejected(self):
        self.stage()
        self.git('commit', '-m', 'Undocumented fixture')
        with self.assertRaises(p.Blocked):
            p.verify()

    def test_symlink_mode_blocked(self):
        self.stage()
        oid = self.git('rev-parse', ':change.txt').decode().strip()
        self.git('update-index', '--add', '--cacheinfo', f'120000,{oid},link.txt')
        with self.assertRaises(p.Blocked):
            p.pre_commit()

    def test_publish_exact_sha_without_force_and_readback(self):
        self.checkpoint()
        expected = self.git('rev-parse', 'HEAD').decode().strip()
        self.git('config', 'progress.autopush', 'true')
        real_run = p.run
        calls = []

        def transport(args, **kwargs):
            calls.append(args)
            if args[0] == 'gh':
                return json.dumps({'full_name': p.REPOSITORY, 'private': False, 'archived': False}).encode()
            if 'push' in args:
                return b''
            if 'ls-remote' in args:
                return f'{expected}\trefs/heads/Tony\n'.encode()
            return real_run(args, **kwargs)

        with patch.object(p, 'run', side_effect=transport):
            p.publish()
        pushes = [args for args in calls if 'push' in args]
        self.assertEqual(len(pushes), 1)
        self.assertIn('--no-force', pushes[0])
        self.assertEqual(pushes[0][-1], expected + ':refs/heads/Tony')
        self.assertEqual(json.loads((self.root / '.git/progress-sync.json').read_text())['commit'], expected)

    def test_publish_rejects_wrong_repository_visibility(self):
        self.git('config', 'progress.autopush', 'true')
        real_run = p.run

        def transport(args, **kwargs):
            if args[0] == 'gh':
                return b'{"private":true}'
            return real_run(args, **kwargs)

        with patch.object(p, 'run', side_effect=transport), self.assertRaises(p.Blocked):
            p.publish()

    def test_failed_push_preserves_commit_without_retry(self):
        self.checkpoint()
        expected = self.git('rev-parse', 'HEAD')
        self.git('config', 'progress.autopush', 'true')
        real_run = p.run
        pushes = []

        def transport(args, **kwargs):
            if args[0] == 'gh':
                return json.dumps({'full_name': p.REPOSITORY, 'private': False, 'archived': False}).encode()
            if 'push' in args:
                pushes.append(args)
                raise p.Blocked('Simulated rejected push')
            return real_run(args, **kwargs)

        with patch.object(p, 'run', side_effect=transport), self.assertRaises(p.Blocked):
            p.publish()
        self.assertEqual(len(pushes), 1)
        self.assertEqual(self.git('rev-parse', 'HEAD'), expected)
        self.assertFalse((self.root / '.git/progress-sync.json').exists())

    def test_remote_readback_mismatch_is_not_success(self):
        self.checkpoint()
        self.git('config', 'progress.autopush', 'true')
        real_run = p.run

        def transport(args, **kwargs):
            if args[0] == 'gh':
                return json.dumps({'full_name': p.REPOSITORY, 'private': False, 'archived': False}).encode()
            if 'push' in args:
                return b''
            if 'ls-remote' in args:
                return b'0000000000000000000000000000000000000000\trefs/heads/Tony\n'
            return real_run(args, **kwargs)

        with patch.object(p, 'run', side_effect=transport), self.assertRaises(p.Blocked):
            p.publish()
        self.assertFalse((self.root / '.git/progress-sync.json').exists())


if __name__ == '__main__':
    unittest.main()
