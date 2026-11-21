import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('e2e',Path(__file__).resolve().parents[1]/'web/tests/e2e_pilot.py')
e2e=importlib.util.module_from_spec(spec)
spec.loader.exec_module(e2e)

class RetryTests(unittest.TestCase):
    def test_close_timeout_is_bounded_and_retried(self):
        calls=[]
        def command(*args,**kwargs):
            calls.append((args,kwargs))
            if args == ('close',) and sum(a==('close',) for a,_ in calls)==1:
                raise e2e.StepFailed('10060')
            if args == ('session','list','--json'):
                return '{"data":{"sessions":[]}}'
            return ''
        with patch.object(e2e,'ab',command):
            e2e.close_browser(timeout=1)
        closes=[kwargs for args,kwargs in calls if args==('close',)]
        self.assertEqual(2,len(closes))
        self.assertTrue(all(c.get('timeout',45)<=1 for c in closes))

if __name__=='__main__': unittest.main()
