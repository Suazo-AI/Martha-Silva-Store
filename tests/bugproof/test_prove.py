"""Offline fixtures exercise real git revisions and real test processes."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'tools/bugproof/prove.py'
spec = importlib.util.spec_from_file_location('prove', SCRIPT)
proof = importlib.util.module_from_spec(spec)
spec.loader.exec_module(proof)
TEST = '''import unittest
from product import add
class Regression(unittest.TestCase):
    def test_sum(self):
        self.assertEqual(add(2, 3), 5)
if __name__ == '__main__': unittest.main()
'''


class ProofTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        # Fixture commits never inherit real repository hooks.
        self.git('config', 'core.hooksPath', str(self.repo / 'no-hooks'))

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.STDOUT).decode().strip()

    def write(self, path, content):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8')

    def commit(self, message):
        self.git('add', '.')
        self.git('commit', '--allow-empty', '-qm', message)
        return self.git('rev-parse', 'HEAD')

    def scenario(self, broken_base=True, fixed_head=True, test=True):
        self.write('product.py', 'def add(a,b): return a ' + ('-' if broken_base else '+') + ' b\n')
        base = self.commit('bug')
        if test:
            self.write('tests/test_sum.py', TEST)
        else:
            self.write('note.txt', 'no test')
        self.commit('red test')
        self.write('product.py', 'def add(a,b): return a ' + ('+' if fixed_head else '*') + ' b\n')
        head = self.commit('fix')
        return base, head

    def test_base_fails_head_passes(self):
        result = proof.prove(self.repo, *self.scenario())
        self.assertEqual(result['verdict'], 'PASS')
        self.assertEqual((result['tests'][0]['base'], result['tests'][0]['head']), ('FAIL', 'PASS'))

    def test_base_passes_is_not_reproduction(self):
        result = proof.prove(self.repo, *self.scenario(False, True))
        self.assertEqual((result['tests'][0]['base'], result['tests'][0]['head']), ('PASS', 'PASS'))
        self.assertEqual(result['verdict'], 'FAIL')

    def test_head_fails(self):
        self.assertEqual(proof.prove(self.repo, *self.scenario(True, False))['verdict'], 'FAIL')

    def test_no_changed_test(self):
        self.assertEqual(proof.prove(self.repo, *self.scenario(test=False))['verdict'], 'FAIL')

    def test_sql_is_skipped_never_proof(self):
        self.write('seed', 'base')
        base = self.commit('base')
        self.write('backend/tests/Fake/SqlTests.cs', 'class SqlTests { }')
        head = self.commit('SQL gated')
        result = proof.prove(self.repo, base, head)
        self.assertEqual(result['tests'][0]['verdict'], 'SKIPPED')
        self.assertEqual(result['verdict'], 'FAIL')

    def test_infrastructure_failure_cannot_be_red(self):
        base, head = self.scenario()
        self.write('tests/test_sum.py', TEST.replace('from product import add', 'from nonexistent import add'))
        head = self.commit('broken import')
        result = proof.prove(self.repo, base, head)
        self.assertEqual(result['tests'][0]['base'], 'ERROR')
        self.assertEqual(result['verdict'], 'FAIL')

    def test_node_adapter(self):
        self.write('product.mjs', 'export const add = (a,b) => a-b;')
        base = self.commit('node bug')
        self.write('tests/sum.test.mjs', "import {test} from 'node:test'; import assert from 'node:assert/strict'; import {add} from '../product.mjs'; test('sum',()=>assert.equal(add(2,3),5));")
        self.commit('node red')
        self.write('product.mjs', 'export const add = (a,b) => a+b;')
        head = self.commit('node fix')
        self.assertEqual(proof.prove(self.repo, base, head)['verdict'], 'PASS')

    def test_a6_demo(self):
        base, head = self.scenario()
        output = self.repo / 'report'
        def cli(candidate):
            p = subprocess.run([sys.executable, str(SCRIPT), '--repo', str(self.repo), '--base', base,
                                '--head', candidate, '--output', str(output)], capture_output=True, text=True)
            return p.returncode, json.loads((output / 'report.json').read_text())
        code, result = cli(head)
        self.assertEqual((code, result['verdict']), (0, 'PASS'))
        self.git('revert', '--no-edit', head)
        code, result = cli(self.git('rev-parse', 'HEAD'))
        self.assertEqual((code, result['verdict']), (1, 'FAIL'))
        self.assertIn('<table>', (output / 'report.html').read_text())
        print('A6: seeded bug + red test + fix => PASS (exit 0); reverted fix => FAIL (exit 1)')


if __name__ == '__main__':
    unittest.main()
