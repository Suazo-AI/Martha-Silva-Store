import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('control', ROOT / 'tools/bugproof/github.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


class ControlTests(unittest.TestCase):
    def workflow_gate(self, labels, body, base_tools):
        workflow = (ROOT / '.github/workflows/bug-proof.yml').read_text(encoding='utf-8')
        step = workflow.split('        id: gate\n', 1)[1].split('      - uses:', 1)[0]
        if "python - <<'PY'" in step:
            code = textwrap.dedent(step.split("python - <<'PY'\n", 1)[1].rsplit('          PY', 1)[0])
            command = [sys.executable, '-c', code]
        else:
            command = [sys.executable, *shlex.split(step.split('run:', 1)[1].strip())[1:]]
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            if base_tools:
                for name in ('github.py', 'prove.py'):
                    target = directory / 'tools/bugproof' / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text('')
            event = directory / 'event.json'
            event.write_text(json.dumps({'pull_request': {'labels': labels, 'body': body}}))
            output = directory / 'out'
            result = subprocess.run(command, cwd=tmp,
                env={**os.environ, 'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)},
                capture_output=True, text=True)
            return result, output.read_text() if output.exists() else ''

    def test_workflow_bootstrap_ordinary_rollup_needs_no_base_scripts(self):
        result, output = self.workflow_gate([], 'Current product integration', False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, 'required=false\n')

    def test_workflow_bootstrap_cannot_bypass_required_bug_proof(self):
        for labels, body in [([{'name': 'bug'}], ''), ([], 'Fixes #12'), ([], 'CLOSES #1')]:
            with self.subTest(labels=labels, body=body):
                result, _ = self.workflow_gate(labels, body, False)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Base branch lacks trusted bug-proof tooling', result.stdout)

    def test_workflow_gate_preserves_original_requirement(self):
        for labels, body, required in [([], None, False), ([], 'Fixes #12', True),
                                      ([{'name': 'bug'}], '', True), ([], 'ordinary change', False)]:
            with self.subTest(labels=labels, body=body):
                result, output = self.workflow_gate(labels, body, True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, 'required=' + str(required).lower() + '\n')

    def test_gate_label_and_reference(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'out'
            with patch.dict(os.environ, {'GITHUB_OUTPUT': str(output)}):
                for labels, body, required in [([], 'Fixes #12', True), ([], 'Closes #1', True),
                                                ([{'name': 'bug'}], '', True), ([], 'ordinary change', False)]:
                    output.write_text('')
                    control.gate({'pull_request': {'labels': labels, 'body': body}}, '')
                    self.assertEqual(output.read_text().strip(), 'required=' + str(required).lower())

    def test_intake_updates_same_job_issue_and_reopens(self):
        run = {'conclusion': 'failure', 'head_branch': 'Tony', 'head_repository': {'full_name': 'owner/repo'},
               'id': 1, 'workflow_id': 42, 'name': 'CI', 'head_sha': 'abc'}
        jobs = [{'name': 'unit', 'conclusion': 'failure', 'html_url': 'https://github.com/job/1'}]
        issues = []
        mutations = []
        def api(method, path, body=None):
            if method == 'GET':
                return {'jobs': jobs}
            mutations.append((method, body))
            if method == 'POST':
                return dict(body, number=7)
            return body
        with patch.dict(os.environ, {'GITHUB_REPOSITORY': 'owner/repo'}), patch.object(control, 'api', side_effect=api), patch.object(control, 'pages', return_value=issues):
            control.intake({'workflow_run': run}, '/repos/owner/repo')
            control.intake({'workflow_run': run}, '/repos/owner/repo')
        self.assertEqual([m[0] for m in mutations], ['POST', 'PATCH'])
        self.assertEqual(mutations[1][1]['state'], 'open')
        self.assertIn('https://github.com/job/1', mutations[1][1]['body'])

    def test_dotnet_class_filter_and_trx(self):
        spec = importlib.util.spec_from_file_location('proof', ROOT / 'tools/bugproof/prove.py')
        proof = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(proof)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            project = root / 'backend/tests/Fake'
            project.mkdir(parents=True)
            (project / 'Fake.csproj').write_text('<Project/>')
            (project / 'ExampleTests.cs').write_text('public class ExampleTests {}')
            def run(args, cwd, env):
                self.assertIn('FullyQualifiedName~.ExampleTests.', args)
                results = Path(args[-1])
                results.mkdir(exist_ok=True)
                (results / 'test.trx').write_text('<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010"><Results><UnitTestResult outcome="Passed"/></Results></TestRun>')
                return 0, 'passed'
            with patch.object(proof, 'run', side_effect=run):
                self.assertEqual(proof.execute(root, 'backend/tests/Fake/ExampleTests.cs', 'dotnet')[0], 'PASS')


if __name__ == '__main__':
    unittest.main()
