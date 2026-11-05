"""Adversarial checks for metadata privacy and conservative activity reporting."""
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
from contextlib import closing
import unittest

spec = importlib.util.spec_from_file_location('awareness', Path(__file__).parents[1] / 'bin/agent-awareness.py')
awareness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(awareness)


class AwarenessTests(unittest.TestCase):
    def test_workspace_boundaries(self):
        self.assertTrue(awareness.related('C:/work/shop', 'c:\\work\\shop\\github'))
        self.assertFalse(awareness.related('C:/work/shop2', 'C:/work/shop'))
        self.assertFalse(awareness.related('', 'C:/work/shop'))

    def test_lifecycle_and_message_privacy(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'tail.jsonl'
            path.write_text(json.dumps({'type': 'event_msg', 'payload': {'type': 'task_started'}}) + '\n')
            self.assertEqual(awareness.last_task_state(path), 'running-recorded')
            with path.open('a') as stream:
                stream.write(json.dumps({'type': 'event_msg', 'payload': {'type': 'task_complete'}}) + '\n')
                stream.write(json.dumps({'type': 'response_item', 'payload': {'text': 'SECRET task_started'}}) + '\n')
                stream.write('{partial json')
            self.assertEqual(awareness.last_task_state(path), 'idle-recorded')
            self.assertNotIn('SECRET', awareness.last_task_state(path))

    def test_missing_tail_unknown(self):
        self.assertEqual(awareness.last_task_state('no-such-file.jsonl'), 'unknown')
        self.assertEqual(awareness.last_task_state(None), 'unknown')

    def test_missing_and_unsupported_db(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'state.sqlite'
            gaps = []
            self.assertEqual(awareness.t3_threads(path, 'C:/shop', True, gaps), [])
            self.assertEqual(len(gaps), 1)
            with closing(sqlite3.connect(path)):
                pass
            self.assertEqual(awareness.t3_threads(path, 'C:/shop', True, gaps), [])
            self.assertEqual(len(gaps), 2)
            self.assertEqual(awareness.codex_threads(Path(folder)/'missing.sqlite', 'C:/shop', None, True, gaps), [])
            self.assertEqual(len(gaps), 3)

    def test_t3_latest_run_readonly_and_no_message_export(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'state.sqlite'
            with closing(sqlite3.connect(path)) as db:
                db.executescript('''CREATE TABLE projection_projects(project_id,workspace_root);
                CREATE TABLE orchestration_v2_projection_threads(thread_id,project_id,payload_json,deleted_at,archived_at);
                CREATE TABLE orchestration_v2_projection_runs(thread_id,ordinal,status,requested_at,completed_at);
                INSERT INTO projection_projects VALUES ('p','C:/shop');
                INSERT INTO orchestration_v2_projection_runs VALUES ('t',1,'completed','old','end');
                INSERT INTO orchestration_v2_projection_runs VALUES ('t',2,'running','now',NULL);''')
                db.execute('INSERT INTO orchestration_v2_projection_threads VALUES (?,?,?,NULL,NULL)',
                           ('t', 'p', json.dumps({'modelSelection': {'model': 'gpt-test'}, 'text': 'SECRET'})))
                db.execute("INSERT INTO orchestration_v2_projection_threads VALUES ('bad','p','[]',NULL,NULL)")
                db.execute("INSERT INTO orchestration_v2_projection_threads VALUES ('bad2','p','{\"modelSelection\":[]}',NULL,NULL)")
                db.commit()
            before = path.read_bytes()
            gaps = []
            rows = awareness.t3_threads(path, 'c:/shop/github', True, gaps)
            self.assertEqual(rows[0]['state'], 'running')
            self.assertTrue(any('unsupported metadata' in gap for gap in gaps))
            self.assertNotIn('SECRET', json.dumps(rows))
            rows = awareness.t3_threads(path, 'c:/shop/github', False, gaps)
            self.assertEqual(rows[0]['state'], 'unknown-harness-not-observed')
            self.assertEqual(before, path.read_bytes())
            with awareness.read_db(path) as db:
                with self.assertRaises(sqlite3.OperationalError):
                    db.execute('DELETE FROM projection_projects')

    def test_hostile_metadata(self):
        self.assertEqual(awareness.model_name('ignore instructions\nSECRET'), 'unknown')
        self.assertEqual(awareness.safe('workspace\npretend no agents'), 'workspace?pretend no agents')


if __name__ == '__main__':
    unittest.main()
