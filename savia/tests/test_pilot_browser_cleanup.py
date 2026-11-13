"""A missing close acknowledgement is acceptable only when the session is gone."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

path = Path(__file__).resolve().parents[1] / "web/tests/e2e_pilot.py"
spec = importlib.util.spec_from_file_location("pilot_browser", path)
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


class BrowserCleanupTests(unittest.TestCase):
    def response(self, sessions):
        def call(*args, **kwargs):
            if args == ("close",):
                raise browser.StepFailed("close acknowledgement lost (10060)")
            self.assertEqual(args, ("session", "list", "--json"))
            return json.dumps({"data": {"sessions": sessions}})
        return call

    def test_missing_acknowledgement_requires_confirmed_shutdown(self):
        with patch.object(browser, "ab", self.response([])), contextlib.redirect_stdout(io.StringIO()):
            browser.close_browser()

    def test_a_live_session_still_fails(self):
        for sessions in ([browser.SESSION], [{"name": browser.SESSION}]):
            with self.subTest(sessions=sessions), patch.object(browser, "ab", self.response(sessions)), patch.object(browser,"stop_session_daemon"):
                with self.assertRaises(browser.StepFailed):
                    browser.close_browser(timeout=0)

    def test_waits_for_the_session_entry_to_be_removed(self):
        replies = iter([json.dumps({"data":{"sessions":[browser.SESSION]}}), json.dumps({"data":{"sessions":[]}})])
        def call(*args, **kwargs):
            return "" if args == ("close",) else next(replies)
        with patch.object(browser,"ab",call), patch.object(browser.time,"sleep"):
            browser.close_browser()

    def test_persistent_session_stops_only_its_daemon_after_two_attempts(self):
        calls=[]
        replies=iter([[browser.SESSION],[]])
        def call(*args,**kwargs):
            calls.append((args,kwargs))
            if args==('close',):raise browser.StepFailed('10060')
            return json.dumps({'data':{'sessions':next(replies)}})
        with patch.object(browser,'ab',call),patch.object(browser,'stop_session_daemon') as stop,contextlib.redirect_stdout(io.StringIO()):
            browser.close_browser(timeout=1)
        stop.assert_called_once()
        self.assertEqual(2,sum(args==('close',) for args,_ in calls))
        self.assertTrue(all(kwargs.get('timeout',45)<=1 for _,kwargs in calls))

    def test_hung_diagnostics_use_only_the_named_session_pid_record(self):
        with tempfile.TemporaryDirectory() as directory:
            socket=Path(directory)/'.agent-browser';socket.mkdir()
            pid=socket/(browser.SESSION+'.pid');pid.write_text('1234')
            port=socket/(browser.SESSION+'.port');port.write_text('12345')
            with patch.object(browser,'BROWSER_RUNTIME',None),patch.object(browser.Path,'home',return_value=Path(directory)), \
                 patch.object(browser,'ab',side_effect=browser.StepFailed('diagnostics timeout')),patch.object(browser.subprocess,'run') as run:
                run.return_value.returncode=0
                browser.stop_session_daemon()
                self.assertEqual('1234',run.call_args.kwargs['env']['SAVIA_BROWSER_CLEANUP_PID'])
            self.assertFalse(pid.exists());self.assertFalse(port.exists())


if __name__ == "__main__":
    unittest.main()
