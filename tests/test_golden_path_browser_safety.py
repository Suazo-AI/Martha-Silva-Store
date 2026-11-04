"""C6 boundary/failure checks. Stdlib only; no browser, SQL, API or service starts."""
import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

from test_golden_path_safety import GP


KEY = '11111111-1111-4111-8111-111111111111'
SALE = '22222222-2222-4222-8222-222222222222'
LOST_KEY = '33333333-3333-4333-8333-333333333333'
LOST_SALE = '44444444-4444-4444-8444-444444444444'


def checkpoint(name='browser.start', posts=0):
    return {'step': name, 'notes': {'dom': sorted(GP.BROWSER_DOM[name]), 'network': [], 'sale_posts': posts,
                                    'external_requests': 0, 'runtime_errors': 0}, 'secrets': ['private-csrf-value']}


class BrowserSafetyTests(unittest.TestCase):
    def test_private_secret_is_registered_but_not_returned_in_notes(self):
        event, secrets = checkpoint(), set()
        notes = GP.browser_checkpoint(event, 'browser.start', secrets)
        self.assertEqual(secrets, {'private-csrf-value'})
        self.assertNotIn('private-csrf-value', json.dumps(notes))

    def reject(self, event):
        with self.assertRaisesRegex(GP.HarnessError, '^browser_protocol_invalid$'):
            GP.browser_checkpoint(event, 'browser.start', set())

    def test_rejects_raw_exception_event(self):
        self.reject({'error': 'request failed: Cookie=private-csrf-value'})

    def test_rejects_out_of_order_checkpoint(self):
        self.reject(checkpoint('browser.cashier_login'))

    def test_rejects_missing_dom_confirmation(self):
        event = checkpoint(); event['notes']['dom'] = []
        self.reject(event)

    def test_rejects_unknown_evidence_field(self):
        event = checkpoint(); event['notes']['request_body'] = 'private-csrf-value'
        self.reject(event)

    def test_rejects_secret_in_arbitrary_path(self):
        event = checkpoint()
        event['notes']['network'] = [{'method': 'GET', 'path': '/private-csrf-value',
                                     'status': 200, 'key': None, 'response_lost': False}]
        self.reject(event)

    def test_rejects_raw_headers_in_network(self):
        event = checkpoint()
        event['notes']['network'] = [{'method': 'GET', 'path': '/internal/login', 'status': 200,
                                     'key': None, 'response_lost': False, 'cookie': 'private-csrf-value'}]
        self.reject(event)

    def test_rejects_missing_runtime_guards(self):
        event = checkpoint(); del event['notes']['external_requests']
        self.reject(event)

    def test_rejects_false_status_and_non_uuid_key(self):
        for key, status in ((KEY, True), ('private-csrf-value', 200)):
            event = checkpoint()
            event['notes']['network'] = [{'method': 'POST', 'path': '/internal/api/commerce/sales',
                                         'status': status, 'key': key, 'response_lost': False}]
            self.reject(event)

    def prepare(self):
        directory = tempfile.TemporaryDirectory(); self.addCleanup(directory.cleanup)
        base = Path(directory.name)
        package = base / 'playwright'; package.mkdir()
        (package / 'index.mjs').write_text('')
        (package / 'package.json').write_text('{}')
        args = types.SimpleNamespace(out=str(base / 'out'), database=None, mode='browser', no_build=True,
                                     keep_private_log=None, playwright_directory=str(package))
        harness = GP.GoldenPath(args)
        self.addCleanup(GP.shutil.rmtree, harness.private, True)
        (harness.out / 'cert.pem').write_text('test certificate placeholder')
        harness.api_dll = base / 'api.dll'; harness.api_dll.write_bytes(b'synthetic unit fixture')
        harness.base_url = 'https://127.0.0.1:12345'
        harness.users = {'Cashier': {'loginName': 'unit.cashier', 'password': 'unit-private-password'}}
        harness.ids = {'location': KEY, 'items': [SALE]}
        harness.database_created = True
        harness.stop_browser = Mock()
        process = Mock(stdin=io.BytesIO())
        process.wait.return_value = 0
        process.poll.return_value = None
        hashes = {name: hashlib.sha256((GP.ROOT / name).read_bytes()).hexdigest() for name in GP.BROWSER_SOURCES}
        return harness, process, hashes

    def run_child(self, harness, process, chunks, clock=None):
        with patch.object(GP.shutil, 'which', return_value='/existing-tool'), \
             patch.object(GP.subprocess, 'run', return_value=types.SimpleNamespace(stdout=b'public-fixture')), \
             patch.object(GP.subprocess, 'Popen', return_value=process), \
             patch.object(GP.select, 'select', return_value=([process.stdout], [], [])), \
             patch.object(GP.os, 'read', side_effect=chunks), contextlib.redirect_stdout(io.StringIO()):
            if clock:
                with patch.object(GP.time, 'monotonic', side_effect=clock):
                    harness.browser()
            else:
                harness.browser()

    def test_sql_rejects_uncommitted_lost_response_before_any_recovery_ack(self):
        harness, process, hashes = self.prepare()
        events, counts = [], []
        for index, name in enumerate(GP.BROWSER_STEPS[:7]):
            sales = 0 if index < 3 else 1 if index < 6 else 2
            event = checkpoint(name, sales)
            if index in (0, 1): event['notes']['source_hashes'] = hashes
            if index == 0: event['notes']['runtime'] = {'chrome': 'Chrome/1.2.3', 'node': 'v24.0.0', 'playwright': '1.63.0'}
            if name in ('browser.inventory', 'browser.stock_after_sale'):
                event['notes'].update(stock_rows=3, stock_total=30 if sales == 0 else 28)
            if name in ('browser.sale_confirmed', 'browser.response_loss_committed'):
                key, sale, quantity = (KEY, SALE, 2) if sales == 1 else (LOST_KEY, LOST_SALE, 1)
                event['notes'].update(key=key, sale_id=sale, quantity=quantity, total_minor=1250 * quantity)
                event['notes']['network'].append({'method': 'POST', 'path': '/internal/api/commerce/sales',
                    'status': 200, 'key': key, 'response_lost': sales == 2})
            if name == 'browser.receipt_reload': event['notes']['sale_id'] = SALE
            events.append((json.dumps(event) + '\n').encode())
            # The child claims the second sale committed. SQL independently still sees only one.
            actual = min(sales, 1)
            counts.append({**dict.fromkeys(GP.ALWAYS_ZERO, 0), 'migrations_applied': 2, 'sales': actual,
                'sale_lines': actual, 'sale_movements': actual, 'sale_operations': actual,
                'movements': 3 + actual, 'operations': 10 + actual,
                'on_hand_total': 30 if actual == 0 else 28, 'active_sessions': 0 if index == 0 else 1})
        harness.oracles = Mock(side_effect=counts)
        with self.assertRaisesRegex(GP.HarnessError, 'oráculo SQL falló en browser.response_loss_committed'):
            self.run_child(harness, process, events)
        sent = [json.loads(line) for line in process.stdin.getvalue().splitlines()]
        self.assertEqual(sum(message == {'ok': True} for message in sent), 6)
        self.assertEqual(harness.steps[-1]['status'], 'FAIL')
        self.assertNotIn('browser.recover_after_reload', [step['step'] for step in harness.steps])
        harness.stop_browser.assert_called_once()

    def test_timeout_stops_browser_before_teardown(self):
        harness, process, _ = self.prepare()
        with self.assertRaisesRegex(GP.HarnessError, '^browser_timeout$'):
            self.run_child(harness, process, [], clock=[0, 200, 400, 600])
        harness.stop_browser.assert_called_once()
        self.assertEqual(harness.steps[-1]['status'], 'FAIL')

    def test_stop_kills_owned_process_group_after_wait_timeout(self):
        harness, process, _ = self.prepare()
        del harness.stop_browser
        harness.browser_process = process
        process.pid = 12345
        process.wait.side_effect = [GP.subprocess.TimeoutExpired('node', 5), 0]
        process.returncode = -9
        with patch.object(GP.os, 'killpg', create=True) as kill, patch.object(GP.signal, 'SIGKILL', 9, create=True):
            self.assertEqual(harness.stop_browser(), -9)
            self.assertEqual(harness.stop_browser(), -9)
            self.assertIsNone(harness.browser_process)
            self.assertEqual(kill.call_count, 2)
        self.assertEqual(kill.call_args_list[0].args, (12345, GP.signal.SIGTERM))
        self.assertEqual(kill.call_args_list[1].args, (12345, 9))
        self.assertTrue(process.stdin.closed)
        process.stdout.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
