"""A missing close acknowledgement is acceptable only when the session is gone."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
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
            with self.subTest(sessions=sessions), patch.object(browser, "ab", self.response(sessions)):
                with self.assertRaises(browser.StepFailed):
                    browser.close_browser(timeout=0)

    def test_waits_for_the_session_entry_to_be_removed(self):
        replies = iter([json.dumps({"data":{"sessions":[browser.SESSION]}}), json.dumps({"data":{"sessions":[]}})])
        def call(*args, **kwargs):
            return "" if args == ("close",) else next(replies)
        with patch.object(browser,"ab",call), patch.object(browser.time,"sleep"):
            browser.close_browser()


if __name__ == "__main__":
    unittest.main()
