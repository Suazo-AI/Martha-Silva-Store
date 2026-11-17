"""Execute workflow Bash and the harness argparse seam only. No runtime or YAML dependency.

The narrow reader rejects unsupported step formatting rather than guessing YAML.
Git Bash is used on Windows; CI uses its installed Bash. No tools are installed.
"""
import argparse
import ast
import contextlib
import hashlib
import io
import os
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/golden-path.yml'
HARNESS = ROOT / 'tests/golden-path/golden_path.py'
GUARD = 'Refuse invalid combined-journey inputs before runtime'
OFFLINE = 'Evidence and cleanup failure regressions (stdlib only)'
C6 = 'C6 Chrome to real API to SQL, including lost-response recovery without a second sale'


def steps(source):
    chunks = re.split(r'(?=^      - (?:name|uses): )', source, flags=re.M)[1:]
    return {chunk.splitlines()[0].split(': ', 1)[1]: chunk for chunk in chunks}


def shell(chunk):
    block = chunk.split('        run: |\n', 1)[1]
    lines = []
    for line in block.splitlines():
        if line and not line.startswith('          '):
            break
        lines.append(line[10:])
    return '\n'.join(lines) + '\n'


def environment(source, event, supply=False, stock=False):
    # Evaluate the actual two GitHub boolean expressions, in a closed namespace.
    values = {'github.event_name': repr(event), 'inputs.supply_receipt': str(supply),
              'inputs.stock_exception': str(stock)}
    result = {}
    for key, expr in re.findall(r'^      (RUN_\w+): \$\{\{ (.+?) \}\}$', source, re.M):
        for name, value in values.items():
            expr = expr.replace(name, value)
        expr = re.sub(r'\btrue\b', 'True', expr)
        expr = re.sub(r'\bfalse\b', 'False', expr)
        expr = expr.replace('&&', ' and ').replace('||', ' or ')
        tree = ast.parse(expr, mode='eval')
        allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
                   ast.Eq, ast.NotEq, ast.Constant, ast.Load)
        if any(not isinstance(node, allowed) for node in ast.walk(tree)):
            raise AssertionError('Unsupported workflow expression')
        result[key] = str(bool(eval(compile(tree, '<workflow env>', 'eval'),
                                   {'__builtins__': {}}, {}))).lower()
    if set(result) != {'RUN_SUPPLY_RECEIPT', 'RUN_STOCK_EXCEPTION'}:
        raise AssertionError('Workflow journey environment missing')
    return result


def bash(script, env):
    executable = ('C:/Program Files/Git/bin/bash.exe' if os.name == 'nt'
                  else shutil.which('bash'))
    if not executable or not Path(executable).is_file():
        raise AssertionError('Installed Bash is required; no install or skip')
    # Prevent ambient SQL settings or shell startup hooks from reaching this seam.
    clean = {key: value for key, value in os.environ.items()
             if key in ('PATH', 'SystemRoot', 'TEMP', 'TMP', 'WINDIR')}
    clean.update(env, RUNNER_TEMP='/offline', MARTHA_TEST_SQL_CONNECTION='offline-sentinel')
    return subprocess.run([executable, '--noprofile', '--norc', '-c', script],
                          env=clean, capture_output=True, timeout=15)


def command(source, env):
    # Execute the real array construction and invocation. Intercept only python3,
    # capturing its argv with NUL separators; never launch the harness process.
    capture = "python3() { printf '%s\\0' \"$@\"; };\n"
    run = bash(capture + shell(steps(source)[C6]), env)
    if run.returncode:
        raise AssertionError(run.stderr.decode())
    argv = run.stdout.decode().rstrip('\0').split('\0')
    if argv[0] != 'tests/golden-path/golden_path.py':
        raise AssertionError('C6 did not invoke the actual harness')
    return argv[1:]


def parse_contract(argv):
    # Compile the actual main parser and ALL guards before the first runtime
    # boundary (optional connection-file loading). No harness imports execute.
    tree = ast.parse(HARNESS.read_text(encoding='utf-8'))
    main = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                and node.name == 'main')
    boundary = next(i for i, node in enumerate(main.body)
                    if isinstance(node, ast.If) and isinstance(node.test, ast.Attribute)
                    and ast.unparse(node.test) == 'args.sql_env_file')
    main.body = main.body[:boundary] + [ast.Return(value=ast.Name(id='args', ctx=ast.Load()))]
    module = ast.fix_missing_locations(ast.Module(body=[main], type_ignores=[]))
    scope = {'argparse': argparse, 'Path': Path, '__doc__': 'offline parser seam'}
    exec(compile(module, str(HARNESS), 'exec'), scope)
    return scope['main'](argv)


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding='utf-8')

    def test_event_input_matrix(self):
        for event, supply, stock, accepted in (
            ('pull_request', False, False, True), ('push', False, False, True),
            ('workflow_dispatch', True, True, True),
            ('workflow_dispatch', True, False, False),
            ('workflow_dispatch', False, True, False),
            ('workflow_dispatch', False, False, False),
        ):
            with self.subTest(event=event, supply=supply, stock=stock):
                env = environment(self.source, event, supply, stock)
                guard = bash(shell(steps(self.source)[GUARD]), env)
                self.assertEqual(guard.returncode, 0 if accepted else 1,
                                 guard.stdout.decode() + guard.stderr.decode())
                if accepted:
                    args = parse_contract(command(self.source, env))
                    self.assertEqual(args.mode, 'browser')
                    self.assertTrue(args.cash and args.supply and args.stock_exception)
                    self.assertTrue(args.no_build)
                    self.assertEqual(args.out, '/offline/c6-evidence')
                    self.assertEqual(args.playwright_directory,
                                     '/offline/c6-playwright/node_modules/playwright')
                else:
                    self.assertIn(b'::error::', guard.stdout)

    def test_original_automatic_flags_fail_actual_parser(self):
        # Original workflow's automatic expression results were both false.
        argv = command(self.source, {'RUN_SUPPLY_RECEIPT': 'false',
                                     'RUN_STOCK_EXCEPTION': 'false'})
        # Keep the negative control even after C6 becomes unconditional.
        argv = [arg for arg in argv if arg not in ('--supply', '--stock-exception')]
        error = io.StringIO()
        with contextlib.redirect_stderr(error), self.assertRaises(SystemExit) as failure:
            parse_contract(argv)
        self.assertEqual(failure.exception.code, 2)
        self.assertIn('--cash requires --mode browser --supply --stock-exception', error.getvalue())

    def test_historical_browser_is_rejected(self):
        argv = command(self.source, environment(self.source, 'workflow_dispatch', True, True))
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
            parse_contract([arg for arg in argv if arg != '--cash'])
        self.assertEqual(failure.exception.code, 2)

    def test_gate_and_offline_regressions_precede_all_runtime(self):
        names = list(steps(self.source))
        self.assertEqual(names.index(GUARD), 1)  # checkout only, before setup/install/SQL
        self.assertEqual(names.index(OFFLINE), 2)
        for name in (GUARD, OFFLINE, C6):
            metadata = steps(self.source)[name].split('        run: |\n', 1)[0]
            self.assertNotIn('continue-on-error:', metadata)
            self.assertNotIn('        if:', metadata)
        script = shell(steps(self.source)[OFFLINE])
        for suite in ('workflow', 'safety', 'browser_safety', 'stock_exception', 'cash', 'cash_evidence'):
            self.assertIn('python3 tests/test_golden_path_' + suite + '.py', script.splitlines())

    def test_missing_connection_fails_before_browser_command(self):
        capture = "unset MARTHA_TEST_SQL_CONNECTION\npython3() { printf 'INVOKED'; };\n"
        result = bash(capture + shell(steps(self.source)[C6]),
                      environment(self.source, 'pull_request'))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(b'INVOKED', result.stdout)
        self.assertIn(b'C6 must not silently skip', result.stderr)

    def test_runtime_protections_unchanged(self):
        # Frozen LF hashes from ba8ff2b. Protect entire unchanged steps, including
        # smoke, SQL oracles/publication, EULA, cert policy, deadlines and teardown.
        protected = PROTECTED_STEPS
        actual = steps(self.source)
        for name, expected in protected.items():
            with self.subTest(step=name):
                self.assertEqual(hashlib.sha256(actual[name].encode()).hexdigest(), expected)
        prefix = self.source.split('    env:\n', 1)[0]
        self.assertEqual(hashlib.sha256(prefix.encode()).hexdigest(), PROTECTED_PREFIX)
        self.assertIn('SQL_IMAGE: mcr.microsoft.com/mssql/server@sha256:'
                      'cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718', self.source)


PROTECTED_STEPS = {'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2': 'f0c8796930ce842c2f47cb8e73dc732c0489a5116532058e4e25de67a6ccec48', 'actions/setup-dotnet@a98b56852c35b8e3190ac28c8c2271da59106c68 # v6.0.0': 'aef3f33663b804d4bbbea57daafdaf14949a648c181027653da4acecc6a91d88', 'Restore pinned dependencies and build the API and the golden-path SQL tool': '9ddb33dad9a2082d8679aadaa23d5a16034233f1056ed387dcdc38e9b66c96f3', 'actions/setup-node@53b83947a5a98c8d113130e565377fae1a50d02f # v6.0.0': '90a0b5b12563bb01361a6caa07f538a135dd323e0d923db05a217ba7355cb532', 'Prepare pinned browser driver without changing the runner trust store': 'e546a9e1c9857915938052054a7bbfc0df4655921e0081b8d40c3af4a42b3cb5', 'Start disposable SQL Server 2022 Developer': 'd79ec2cee5f00302d8257647cbb2adfd6f238d185b174c67b3a57aa6d55ecc08', 'Wait for SQL and verify licensed edition and engine': 'ac6180b96aefee4487d1fdfd5115fe1e3c44b0ee735a960d37b32cabbfd43683', 'Golden path smoke (real API, migrator, roles, idempotent sale, SQL oracles, teardown)': '9b4869d2bd33a410e38d786636dac2950551bfa50fcadea9c9c46666e549844f', 'Verify exact evidence bytes before publication': '9941acdff03723b0a8b803528e54d75aa31439da86ec6fea563a091e8af2bdf0', 'Publish the per-step oracle table to the job summary': 'd1603c0d9d6020540ba8f18f1cfb0f5e37eb85f05ad7f317d3eef8c417f61946', 'Upload sanitized evidence only': 'd8941f8fefc7ad4ddf8a67f4fe592f19e1d29434542859ac2a51f20c9fbbf5c0', 'Verify exact C6 evidence bytes before publication': '279323e81e9ea207d550513881fb3a6727b0d8ee02f3073afbfd624263c377dd', 'Publish the C6 browser checkpoints and SQL oracle table': 'e73ec313d89b1d7b40e9a1fbbd3867d5f4633048bd7011d67750a11bbf1e0927', 'Upload sanitized C6 browser trace and SQL evidence only': 'b6bab219c0c00b59a9f690555d7bc89cbadb3a6cdedc970f013ad74126ba82b4', 'Always destroy the disposable SQL container': '435a1b3d18a03a0ff65965b99a53ef677016647ae8b5b2166c0f14e0a5c029af'}
PROTECTED_PREFIX = '942c510fd1f1ef2c9e9f006c26efb24564921a434e63cc2c31a70b1120aa2e17'

if __name__ == '__main__':
    unittest.main()
