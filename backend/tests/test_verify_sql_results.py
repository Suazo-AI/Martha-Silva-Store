import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from verify_sql_results import EXPECTED, PREFIX, verify


class ResultVerifierTests(unittest.TestCase):
    def check(self, expected, *, skip=False, missing=False, unknown=False, duplicate=False):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            if not missing:
                root = ET.Element("TestRun", xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010")
                summary = ET.SubElement(root, "ResultSummary")
                ET.SubElement(summary, "Counters", total="6", executed="5" if skip else "6",
                              passed="5" if skip else "6", failed="0", notExecuted="1" if skip else "0")
                results = ET.SubElement(root, "Results")
                names = sorted(EXPECTED)
                if duplicate:
                    names[-1] = names[0]
                for index, name in enumerate(names):
                    result = ET.SubElement(results, "UnitTestResult", testName=PREFIX + ("unexpected" if unknown else name),
                                           outcome="NotExecuted" if skip and index == 0 else "Passed")
                    ET.SubElement(result, "Output").text = "DO_NOT_RETAIN_SECRET_SENTINEL"
                ET.ElementTree(root).write(path / "sql.trx")
            self.assertEqual(expected, verify(path))
            safe = (path / "sanitized-results.json").read_text()
            self.assertNotIn("DO_NOT_RETAIN_SECRET_SENTINEL", safe)
            self.assertEqual("passed" if expected else "failed", json.loads(safe)["status"])

    def test_complete_pass(self): self.check(True)
    def test_skip_fails(self): self.check(False, skip=True)
    def test_missing_fails(self): self.check(False, missing=True)
    def test_unknown_fails(self): self.check(False, unknown=True)
    def test_duplicate_fails(self): self.check(False, duplicate=True)


if __name__ == "__main__":
    unittest.main()
