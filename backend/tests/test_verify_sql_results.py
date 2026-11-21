import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET
from verify_sql_results import EXPECTED, verify


class ResultVerifierTests(unittest.TestCase):
    def check(self, expected, *, skip=False, missing=False, unknown=False, duplicate=False,
              omitted=False, wrong_class=False, counters_wrong=False, outcome="Passed"):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            if not missing:
                root = ET.Element("TestRun", xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010")
                summary = ET.SubElement(root, "ResultSummary")
                count = len(EXPECTED)
                ET.SubElement(summary, "Counters", total=str(count), executed=str(count - int(skip)),
                              passed=str(count - int(skip) - int(counters_wrong)), failed="0",
                              notExecuted="1" if skip else "0")
                results = ET.SubElement(root, "Results")
                names = sorted(EXPECTED)
                if duplicate:
                    names[-1] = names[0]
                if omitted:
                    names.pop()
                if wrong_class:
                    names[0] = "Unknown.Class." + names[0].rsplit(".", 1)[-1]
                for index, name in enumerate(names):
                    result = ET.SubElement(results, "UnitTestResult", testName="unexpected" if unknown else name,
                                           outcome="NotExecuted" if skip and index == 0 else outcome)
                    ET.SubElement(result, "Output").text = "DO_NOT_RETAIN_SECRET_SENTINEL"
                ET.ElementTree(root).write(path / "sql.trx")
            self.assertEqual(expected, verify(path))
            safe = (path / "sanitized-results.json").read_text()
            self.assertNotIn("DO_NOT_RETAIN_SECRET_SENTINEL", safe)
            report = json.loads(safe)
            self.assertEqual(len(EXPECTED), report["expectedTests"])
            self.assertEqual("passed" if expected else "failed", report["status"])
            self.assertTrue(all(item["name"] in EXPECTED for item in report["tests"]))

    def test_complete_pass(self): self.check(True)
    def test_skip_fails(self): self.check(False, skip=True)
    def test_missing_fails(self): self.check(False, missing=True)
    def test_unknown_fails(self): self.check(False, unknown=True)
    def test_duplicate_fails(self): self.check(False, duplicate=True)
    def test_omitted_fails_even_with_passing_counters(self): self.check(False, omitted=True)
    def test_wrong_class_cannot_spoof_expected_method(self): self.check(False, wrong_class=True)
    def test_inconsistent_counters_fail(self): self.check(False, counters_wrong=True)
    def test_failed_result_fails_even_with_passing_counters(self): self.check(False, outcome="Failed")
    def test_unknown_outcome_fails(self): self.check(False, outcome="Unrecognized")


if __name__ == "__main__":
    unittest.main()
