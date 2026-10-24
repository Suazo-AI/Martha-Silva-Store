#!/usr/bin/env python3
"""Offline sync safety regressions; all command execution is mocked."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('sync', Path(__file__).resolve().parents[1] / 'tools/sync_progress.py')
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class SyncTests(unittest.TestCase):
    def fake_run(self, args):
        if args[0] == 'gh':
            return b'{"nameWithOwner":"Suazo-AI/Martha-Silva-Store","visibility":"PRIVATE"}'
        if args[0] != 'git':
            return b''
        cmd = args[1:]
        if cmd == ['rev-parse', '--show-toplevel']:
            return str(sync.ROOT).encode() + b'\n'
        if cmd[:1] == ['symbolic-ref']:
            return b'main\n'
        if cmd[:1] == ['remote']:
            return b'https://github.com/Suazo-AI/Martha-Silva-Store.git\n'
        if cmd == ['rev-parse', 'HEAD']:
            return b'abc123\n'
        return b''

    def test_success_checks_before_single_nonforce_push(self):
        with patch.object(sync, 'run', side_effect=self.fake_run) as run:
            sync.synchronize()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(commands[-1], ['git', 'push', '--no-force', '--no-follow-tags', '--no-mirror', 'origin', 'HEAD:main'])
        self.assertEqual(sum('push' in cmd for cmd in commands), 1)
        self.assertIn([sync.sys.executable, 'tests/check.py'], commands)

    def assert_block(self, predicate, output):
        def execute(args):
            return output if predicate(args) else self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute) as run:
            with self.assertRaises(sync.Blocked):
                sync.synchronize()
        self.assertFalse(any('push' in call.args[0] for call in run.call_args_list))

    def test_wrong_branch(self):
        self.assert_block(lambda a: 'symbolic-ref' in a, b'task/work\n')

    def test_wrong_origin(self):
        self.assert_block(lambda a: 'remote' in a, b'https://github.com/other/repo.git\n')

    def test_multiple_push_urls(self):
        self.assert_block(lambda a: '--push' in a, b'https://github.com/Suazo-AI/Martha-Silva-Store.git\nhttps://github.com/other/repo.git\n')

    def test_public_repo(self):
        self.assert_block(lambda a: a[0] == 'gh', b'{"nameWithOwner":"Suazo-AI/Martha-Silva-Store","visibility":"PUBLIC"}')

    def test_dirty_tree(self):
        self.assert_block(lambda a: 'status' in a, b'?? unrelated.txt\n')

    def test_secret_in_outgoing_patch(self):
        self.assert_block(lambda a: 'log' in a, b'-' + b'ghp_' + b'A' * 30)

    def test_secret_in_committed_blob(self):
        def execute(args):
            if 'ls-tree' in args:
                return b'100644 blob abc\tfile.txt\0'
            if 'cat-file' in args:
                return b'ghp_' + b'A' * 30
            return self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute) as run:
            with self.assertRaises(sync.Blocked):
                sync.synchronize()
        self.assertFalse(any('push' in c.args[0] for c in run.call_args_list))

    def test_qa_failure_preserves_commit(self):
        def execute(args):
            if args[0] != 'git' and args[0] != 'gh':
                raise sync.Blocked('QA failed')
            return self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute) as run:
            with self.assertRaises(sync.Blocked):
                sync.synchronize()
        self.assertFalse(any(any(x in c.args[0] for x in ('push', 'reset', 'commit')) for c in run.call_args_list))

    def test_qa_dirty_output_blocks(self):
        statuses = iter([b'', b' M dist/index.html\n'])
        def execute(args):
            return next(statuses) if 'status' in args else self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute):
            with self.assertRaises(sync.Blocked):
                sync.synchronize()

    def test_auth_failure_is_noninteractive_and_redacted(self):
        result = subprocess.CompletedProcess([], 1, b'', b'secret-token-not-for-display')
        with patch.object(sync.subprocess, 'run', return_value=result) as run:
            with self.assertRaises(sync.Blocked) as error:
                sync.run(['git', 'push'])
        self.assertNotIn('secret-token', str(error.exception))
        env = run.call_args.kwargs['env']
        self.assertEqual(env['GIT_TERMINAL_PROMPT'], '0')
        self.assertIn('BatchMode=yes', env['GIT_SSH_COMMAND'])
        self.assertEqual(run.call_count, 1)

    def test_progress_rejects_preexisting_staging(self):
        with patch.object(sync, 'guard_repository'), patch.object(sync, 'git', return_value=b'existing.txt\0') as git:
            with self.assertRaises(sync.Blocked):
                sync.progress('progress', ['file.txt'])
        self.assertEqual(git.call_count, 1)

    def test_progress_rejects_unrelated_changes(self):
        responses = iter([b'', b'a.txt\0b.txt\0', b'b.txt\0'])
        with patch.object(sync, 'guard_repository'), patch.object(sync, 'git', side_effect=lambda *a: next(responses)) as git:
            with self.assertRaises(sync.Blocked):
                sync.progress('progress', ['a.txt'])
        self.assertFalse(any(c.args[0] in ('add', 'commit') for c in git.call_args_list))

    def test_head_changed_during_qa(self):
        heads = iter([b'first', b'second'])
        def execute(args):
            return next(heads) if args == ['git', 'rev-parse', 'HEAD'] else self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute) as run:
            with self.assertRaises(sync.Blocked):
                sync.synchronize()
        self.assertFalse(any('push' in c.args[0] for c in run.call_args_list))

    def test_push_failure_is_not_retried(self):
        def execute(args):
            if 'push' in args:
                raise sync.Blocked('rejected')
            return self.fake_run(args)
        with patch.object(sync, 'run', side_effect=execute) as run:
            with self.assertRaises(sync.Blocked):
                sync.synchronize()
        self.assertEqual(sum('push' in c.args[0] for c in run.call_args_list), 1)

    def test_progress_only_stages_explicit_paths(self):
        def execute(*args):
            if args[0] == 'ls-files' and '--others' not in args:
                return b'a.txt\0'
            if args[:2] == ('diff', '--name-only'):
                return b'a.txt\0'
            return b''
        with patch.object(sync, 'guard_repository'), patch.object(sync, 'validate'), \
                patch.object(sync, 'synchronize') as publish, \
                patch.object(sync, 'git', side_effect=execute) as git:
            sync.progress('a useful change', ['a.txt'])
        self.assertIn(( 'add', '--', 'a.txt'), [c.args for c in git.call_args_list])
        self.assertIn(('-c', 'core.hooksPath=/dev/null', 'commit', '-m', 'a useful change'),
                      [c.args for c in git.call_args_list])
        publish.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
