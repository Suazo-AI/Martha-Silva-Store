"""Fail closed on missing/skipped SQL tests; retain only allowlisted TRX outcomes."""
import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

EXPECTED = {
    "Concurrent_same_key_replays_exact_response_and_conflicting_payload_is_409",
    "Migrated_database_exposes_only_synthetic_catalog_and_seed_is_non_replenishing",
    "Twenty_distinct_requests_for_last_unit_have_exactly_one_winner",
    "Client_supplied_price_total_and_customer_fields_are_rejected_without_mutation",
    "Invalid_quantities_reject_without_any_persistent_change",
    "Failed_insert_rolls_back_stock_and_leaves_no_order_or_idempotency_fragment",
}
PREFIX = "Martha.Store.Api.Tests.SqlServerIntegrationTests."


def verify(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    report = {"status": "failed", "expectedTests": len(EXPECTED), "tests": []}
    try:
        root = ET.parse(directory / "sql.trx").getroot()
        counters = root.find(".//{*}Counters")
        if counters is None:
            raise ValueError("missing counters")
        report["counters"] = {key: int(counters.get(key, "0")) for key in
                              ("total", "executed", "passed", "failed", "notExecuted", "error", "timeout", "aborted")}
        results = root.findall(".//{*}UnitTestResult")
        names = []
        for result in results:
            name = result.get("testName", "")
            if not name.startswith(PREFIX) or name[len(PREFIX):] not in EXPECTED:
                raise ValueError("unexpected test")
            name = name[len(PREFIX):]
            names.append(name)
            outcome = result.get("outcome")
            if outcome not in {"Passed", "Failed", "NotExecuted", "Error", "Timeout", "Aborted", "Inconclusive"}:
                raise ValueError("unexpected outcome")
            # No stdout, error messages, stack traces, connection strings or environment.
            report["tests"].append({"name": name, "outcome": outcome})
        counts = report["counters"]
        passed = (len(names) == len(EXPECTED) and set(names) == EXPECTED
                  and counts["total"] == counts["executed"] == counts["passed"] == len(EXPECTED)
                  and all(counts[k] == 0 for k in ("failed", "notExecuted", "error", "timeout", "aborted"))
                  and all(t["outcome"] == "Passed" for t in report["tests"]))
        report["status"] = "passed" if passed else "failed"
    except (OSError, ET.ParseError, ValueError):
        report["reason"] = "Missing, malformed or unexpected SQL test evidence."
    (directory / "sanitized-results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"SQL Server tests: {report['status']}; expected {len(EXPECTED)} executed, passed, zero skipped.")
    return report["status"] == "passed"


if __name__ == "__main__":
    sys.exit(0 if verify(os.environ["SQL_RESULTS_DIR"]) else 1)
