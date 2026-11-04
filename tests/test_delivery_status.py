"""Regression tests for tools/delivery_status.py (the deterministic delivery digest)."""
import copy
import json
import sys
import tempfile
import unittest
from unittest import mock
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



class InvalidGraphRegressionTests(unittest.TestCase):
    def test_unknown_target_is_rejected_and_never_reported_complete(self):
        data = ledger()
        data['targets'] = [{'id': 'MISSING', 'name': 'missing target'}]
        self.assertIn('target unknown MISSING', ds.validate(data))
        text = ds.render(data, ds.validate(data), {})
        self.assertIn('[!CAUTION]', text)
        self.assertIn('missing target', text)
        self.assertIn('ledger inválido', text)
        self.assertNotIn('completo.', text)

    def test_unknown_target_has_explicit_path_error(self):
        with self.assertRaisesRegex(ValueError, 'unknown target MISSING'):
            ds.critical_path(ledger(), 'MISSING')

    def test_cycle_has_explicit_path_error_and_render_survives(self):
        data = ledger(X={'status': 'todo', 'blocked_by': ['Z']})
        with self.assertRaisesRegex(ValueError, 'dependency cycle'):
            ds.critical_path(data, 'Z')
        text = ds.render(data, ds.validate(data), {})
        self.assertIn('[!CAUTION]', text)
        self.assertIn('ledger inválido', text)
        self.assertIn('dependency cycle', text)
        self.assertIn('### Siguiente acción por persona', text)

    def test_unknown_dependency_has_explicit_path_error_and_render_survives(self):
        data = ledger(Y={'blocked_by': ['MISSING']})
        with self.assertRaisesRegex(ValueError, 'unknown dependency MISSING'):
            ds.critical_path(data, 'Z')
        text = ds.render(data, ds.validate(data), {})
        self.assertIn('Y: blocked_by unknown MISSING', text)
        self.assertIn('ledger inválido', text)
        self.assertIn('### Decisiones que faltan', text)
        self.assertNotIn('completo.', text)

    def test_unknown_dependency_is_not_actionable(self):
        result = ds.actionable(ledger(Y={'blocked_by': ['MISSING']}))
        self.assertNotIn('b', result)
        self.assertNotIn('a', result)

    def test_dropped_prerequisite_is_consistently_satisfied(self):
        dropped = {'status': 'dropped', 'decision_ref': 'decision/retire-x'}
        waiting = ledger(X=dropped)
        self.assertEqual(ds.validate(waiting), [])
        self.assertEqual([i['id'] for i in ds.actionable(waiting)['b']], ['Y'])
        self.assertEqual(ds.critical_path(waiting, 'Z'), ['Y', 'Z'])
        completed = ledger(X=dropped, Y={'status': 'done', 'evidence': 'run/y'},
                           Z={'status': 'done', 'evidence': 'run/z'})
        self.assertEqual(ds.validate(completed), [])
        self.assertEqual(ds.critical_path(completed, 'Z'), [])
        self.assertIn('**Camino crítico a fin:** completo.',
                      ds.render(completed, ds.validate(completed), {}))

    def test_completed_target_with_invalid_ancestry_is_not_reported_complete(self):
        data = ledger(Y={'status': 'done', 'evidence': 'run/y',
                         'blocked_by': ['MISSING']},
                      Z={'status': 'done', 'evidence': 'run/z'})
        text = ds.render(data, ds.validate(data), {})
        self.assertIn('ledger inválido', text)
        self.assertNotIn('completo.', text)


class CliTests(unittest.TestCase):
    def run_cli(self, data, payload, *extra):
        with tempfile.TemporaryDirectory() as tmp:
            ledger_path, event_path, out = Path(tmp, 'l.json'), Path(tmp, 'e.json'), Path(tmp, 'o.md')
            ledger_path.write_text(json.dumps(data))
            event_path.write_text(json.dumps(payload))
            with mock.patch.object(ds, 'event_changes', return_value=([], [])):
                code = ds.main(['--ledger', str(ledger_path), '--event', str(event_path),
                                '--event-name', 'pull_request', '--output', str(out), *extra])
            return code, out.read_text(encoding='utf-8')

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


    def test_invalid_graphs_exit_one_and_write_useful_digest(self):
        cases = {
            'unknown target': ledger(),
            'cycle': ledger(X={'status': 'todo', 'blocked_by': ['Z']}),
            'unknown dependency': ledger(Y={'blocked_by': ['MISSING']}),
        }
        cases['unknown target']['targets'] = [{'id': 'MISSING', 'name': 'fin'}]
        for label, data in cases.items():
            with self.subTest(case=label):
                code, text = self.run_cli(data, self.pr(
                    '## Por qué\n## Alternativas\n## Evidencia\n## Qué falta'))
                self.assertEqual(code, 1)
                self.assertTrue(text.startswith(ds.MARKER))
                self.assertIn('[!CAUTION]', text)
                self.assertIn('ledger inválido', text)
                self.assertIn('### Siguiente acción por persona', text)
                self.assertNotIn('completo.', text)


if __name__ == '__main__':
    unittest.main()
