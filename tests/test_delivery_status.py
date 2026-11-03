"""Regression tests for tools/delivery_status.py (the deterministic delivery digest)."""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import delivery_status as ds  # noqa: E402

BASE = {
    'updated': '2026-11-03',
    'people': {'a': 'Ana', 'b': 'Beto'},
    'tracks': [{'id': 't', 'name': 'Track'}],
    'targets': [{'id': 'Z', 'name': 'fin'}],
    'items': [
        {'id': 'X', 'track': 't', 'owner': 'a', 'status': 'done', 'title': 'x', 'why': 'w', 'done_when': 'd',
         'evidence': 'run/1', 'paths': ['src/x/*']},
        {'id': 'Y', 'track': 't', 'owner': 'b', 'status': 'todo', 'title': 'y', 'why': 'w', 'done_when': 'd',
         'blocked_by': ['X'], 'needs': {'decision': 'pick', 'decider': 'a', 'tool': 'thing'}},
        {'id': 'Z', 'track': 't', 'owner': 'a+b', 'status': 'blocked', 'title': 'z', 'why': 'w', 'done_when': 'd',
         'blocked_by': ['Y']},
    ],
}


def ledger(**changes):
    data = copy.deepcopy(BASE)
    for item_id, fields in changes.items():
        next(i for i in data['items'] if i['id'] == item_id).update(fields)
    return data


class ValidateTests(unittest.TestCase):
    def test_repository_ledger_is_valid(self):
        self.assertEqual(ds.validate(ds.load(ds.DEFAULT_LEDGER)), [])

    def test_base_fixture_is_valid(self):
        self.assertEqual(ds.validate(ledger()), [])

    def test_done_without_evidence_fails(self):
        self.assertIn('X: done without evidence', ds.validate(ledger(X={'evidence': ''})))

    def test_done_before_prerequisite_fails(self):
        errors = ds.validate(ledger(Y={'status': 'done', 'evidence': 'pr/2'}, X={'status': 'todo'}))
        self.assertIn('Y: done while prerequisite X is todo', errors)

    def test_blocked_without_reason_fails(self):
        self.assertIn('Y: blocked without blocked_by or blocker',
                      ds.validate(ledger(Y={'status': 'blocked', 'blocked_by': []})))

    def test_unknown_owner_status_track_and_dependency_fail(self):
        errors = ds.validate(ledger(Y={'owner': 'zz', 'status': 'almost', 'track': 'q', 'blocked_by': ['NOPE']}))
        self.assertTrue(any('unknown owner' in e for e in errors))
        self.assertTrue(any('status must be' in e for e in errors))
        self.assertTrue(any('unknown track' in e for e in errors))
        self.assertIn('Y: blocked_by unknown NOPE', errors)

    def test_cycle_and_duplicate_fail(self):
        data = ledger(X={'blocked_by': ['Z'], 'status': 'todo'})
        data['items'].append(copy.deepcopy(data['items'][0]))
        errors = ds.validate(data)
        self.assertTrue(any(e.startswith('dependency cycle') for e in errors))
        self.assertIn('X: duplicate id', errors)

    def test_dropped_requires_decision(self):
        self.assertIn('Y: dropped without decision_ref', ds.validate(ledger(Y={'status': 'dropped'})))


class DigestTests(unittest.TestCase):
    def test_actionable_respects_prerequisites_and_shared_owners(self):
        result = ds.actionable(ledger())
        self.assertEqual([i['id'] for i in result['b']], ['Y'])
        self.assertNotIn('a', result)  # Z still waits on Y

    def test_critical_path_skips_finished_steps(self):
        self.assertEqual(ds.critical_path(ledger(), 'Z'), ['Y', 'Z'])
        done = ledger(Y={'status': 'done', 'evidence': 'e'}, Z={'status': 'done', 'evidence': 'e'})
        self.assertEqual(ds.critical_path(done, 'Z'), [])

    def test_touched_maps_files_to_gates(self):
        self.assertEqual(ds.touched(ledger(), ['src/x/a.js', 'README.md']), {'X': ['src/x/a.js']})

    def test_pr_sections_accept_accents_and_levels(self):
        body = '## ¿Por qué?\n### Alternativas\n## Evidencia\n## Qué falta\n'
        self.assertEqual(ds.pr_sections_missing(body), [])
        self.assertEqual(ds.pr_sections_missing('## Por qué\n'), ['alternativas', 'evidencia', 'que falta'])
        self.assertEqual(len(ds.pr_sections_missing(None)), 4)

    def test_render_reports_errors_decisions_and_untracked_change(self):
        text = ds.render(ledger(X={'evidence': ''}), ds.validate(ledger(X={'evidence': ''})),
                         {'kind': 'push', 'ref': 'feat', 'actor': 'b', 'head': 'a' * 40,
                          'commits': [['abc1234', 'Beto', 'feat | pipe']], 'files': ['src/x/a.js']})
        self.assertTrue(text.startswith(ds.MARKER))
        self.assertIn('X: done without evidence', text)
        self.assertIn('| Y | Ana | pick |', text)
        self.assertIn('feat \\| pipe', text)
        self.assertIn('no actualiza `docs/pipeline/ledger.json`', text)
        self.assertIn('**Camino crítico a fin** (2 pasos): Y [b] → Z [a+b]', text)


class CliTests(unittest.TestCase):
    def run_cli(self, data, payload, *extra):
        with tempfile.TemporaryDirectory() as tmp:
            ledger_path, event_path, out = Path(tmp, 'l.json'), Path(tmp, 'e.json'), Path(tmp, 'o.md')
            ledger_path.write_text(json.dumps(data))
            event_path.write_text(json.dumps(payload))
            code = ds.main(['--ledger', str(ledger_path), '--event', str(event_path),
                            '--event-name', 'pull_request', '--output', str(out), *extra])
            return code, out.read_text()

    def pr(self, body, draft=False):
        return {'pull_request': {'number': 7, 'title': 't', 'body': body, 'draft': draft,
                                 'user': {'login': 'b'}, 'head': {'ref': 'f', 'sha': 'f' * 40},
                                 'base': {'sha': 'e' * 40}}}

    def test_ready_pr_without_sections_fails_only_when_required(self):
        self.assertEqual(self.run_cli(ledger(), self.pr('no sections'))[0], 0)
        code, text = self.run_cli(ledger(), self.pr('no sections'), '--require-pr-sections')
        self.assertEqual(code, 1)
        self.assertIn('no tiene las secciones', text)

    def test_draft_pr_only_warns(self):
        self.assertEqual(self.run_cli(ledger(), self.pr('x', draft=True), '--require-pr-sections')[0], 0)

    def test_invalid_ledger_fails_cli_but_still_writes_digest(self):
        code, text = self.run_cli(ledger(X={'evidence': ''}), self.pr('## Por qué\n## Alternativas\n## Evidencia\n## Qué falta'))
        self.assertEqual(code, 1)
        self.assertIn('[!CAUTION]', text)


if __name__ == '__main__':
    unittest.main()
