"""Fail closed on missing/skipped SQL tests; retain only allowlisted TRX outcomes."""
import json
import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

PREFIX = "Martha.Store.Api.Tests.SqlServerIntegrationTests."
V2_PREFIX = "Martha.Store.Api.Tests.SaviaSqlServerIntegrationTests."
EXPECTED = {PREFIX + name for name in {
    "Concurrent_same_key_replays_exact_response_and_conflicting_payload_is_409",
    "Migrated_database_exposes_only_synthetic_catalog_and_seed_is_non_replenishing",
    "Twenty_distinct_requests_for_last_unit_have_exactly_one_winner",
    "Client_supplied_price_total_and_customer_fields_are_rejected_without_mutation",
    "Invalid_quantities_reject_without_any_persistent_change",
    "Failed_insert_rolls_back_stock_and_leaves_no_order_or_idempotency_fragment",
}} | {V2_PREFIX + name for name in {
    "Twenty_distinct_reservations_for_last_unit_have_one_winner_and_balanced_ledger",
    "Concurrent_same_key_replays_creation_and_changed_payload_conflicts",
    "Repeated_and_concurrent_cancellation_releases_once_without_changing_on_hand",
    "Failed_reservation_movement_rolls_back_balance_reservation_and_attempt",
    "Failed_cancellation_movement_rolls_back_release_state_and_attempt",
    "Creation_replay_is_original_after_cancellation_while_get_is_current",
    "Lost_response_after_commit_is_recovered_by_lookup_and_stable_retry",
    "Authority_mismatch_cannot_mutate_or_rewrite_persisted_authority",
    "Repeating_seed_preserves_reserved_and_released_balances_and_ledger",
    "Partial_or_inconsistent_seed_is_rejected_without_replenishment",
    "Movement_ledger_reconciles_balances_and_reservation_states",
    "Durable_rejection_replays_after_availability_changes_and_attempt_conflicts",
    "Bulk_ledger_and_attempt_mutations_are_rejected_by_SQL_and_rollback_all_changes",
    "Seed_rejects_orphan_success_attempt_without_reservation_movement_or_valid_receipt",
    "Bulk_creation_receipt_and_fields_cannot_diverge_from_original_replay",
}}


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
            if name not in EXPECTED:
                raise ValueError("unexpected test")
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
