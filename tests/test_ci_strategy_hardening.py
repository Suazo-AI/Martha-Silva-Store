"""Adversarial contracts: fail-closed selection, source identity and release provenance."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "ci_strategy.py"
spec = importlib.util.spec_from_file_location("ci_strategy_under_test", SCRIPT)
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class SelectionHardening(unittest.TestCase):
    def test_golden_path_maps_to_savia_not_storefront(self):
        result = ci.classify(["tests/golden-path/golden_path.py"])
        self.assertTrue(result["run_savia"])
        self.assertFalse(result["run_storefront"])
        self.assertTrue(result["requires_full"])

    def test_savia_demo_and_deployer_are_real_application_paths(self):
        for p in ("savia/demo/api/index.mjs", "savia/deploy/migrator/Program.cs"):
            with self.subTest(p=p):
                result = ci.classify([p])
                self.assertTrue(result["run_savia"])
                self.assertTrue(result["requires_full"])
                self.assertEqual(result["unmapped_paths"], [])

    def test_executable_docs_are_not_silent(self):
        result = ci.classify(["savia/docs/research/charts/verify.py", "docs/notes.md"])
        self.assertEqual(result["executable_documentation"],
                         ["savia/docs/research/charts/verify.py"])
        self.assertIn("savia-docs", result["areas"])

    def test_workflow_and_unknown_changes_are_cross_cutting(self):
        for p in (".github/workflows/ci.yml", "unknown/entry.py"):
            with self.subTest(p=p):
                result = ci.classify([p])
                self.assertTrue(result["run_storefront"])
                self.assertTrue(result["run_savia"])
                self.assertTrue(result["requires_full"])

    def test_ci_strategy_self_test_not_mislabeled_as_storefront(self):
        result = ci.classify(["tests/test_ci_strategy.py"])
        self.assertFalse(result["run_storefront"])
        self.assertFalse(result["run_savia"])
        self.assertTrue(result["requires_full"])

    def test_case_aliases_and_bidi_controls_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "collision"):
            ci.classify(["src/App.js", "src/app.js"])
        self.assertFalse(ci.valid_path("src/\u202eevil.py"))

    def test_root_level_source_change_needs_deep_verification(self):
        self.assertTrue(ci.classify(["src/app.js"])["requires_full"])

    def test_required_gate2_jobs_cannot_be_skipped(self):
        self.assertEqual(ci.evaluate_gate2("success", "true", "false", "success", "skipped"), [])
        for values in (
            ("success", "true", "false", "skipped", "skipped"),
            ("success", "false", "true", "skipped", "skipped"),
            ("success", "", "", "skipped", "skipped"),
            ("failure", "false", "false", "skipped", "skipped"),
            ("success", "false", "false", "success", "skipped"),
        ):
            with self.subTest(values=values):
                self.assertTrue(ci.evaluate_gate2(*values))

    def test_gate2_cli_is_nonzero_on_false_green(self):
        args = [
            sys.executable, str(SCRIPT), "gate2-check", "--g1", "success",
            "--storefront-selected", "true", "--savia-selected", "false",
            "--storefront-result", "skipped", "--savia-result", "skipped",
        ]
        process = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(process.returncode, 2, process.stdout)
        self.assertFalse(json.loads(process.stdout)["selected_tests_passed"])

    def test_symlinked_parent_cannot_escape_checkout(self):
        with tempfile.TemporaryDirectory() as directory, tempfile.TemporaryDirectory() as other:
            root = Path(directory)
            (Path(other) / "escape.py").write_text("x = 42\n", encoding="utf-8")
            (root / "linked").symlink_to(other, target_is_directory=True)
            self.assertEqual(len(ci.static_checks(root, ["linked/escape.py"])), 1)

    def test_git_rename_reports_sensitive_old_and_new_names(self):
        def git(root, *args):
            return subprocess.run(["git", "-C", str(root), *args], check=True,
                                  capture_output=True, text=True).stdout.strip()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            git(root, "init", "-q")
            initial = root / "savia" / "db" / "migrations" / "V999.sql"
            initial.parent.mkdir(parents=True)
            initial.write_text("SELECT 1;\n", encoding="utf-8")
            git(root, "add", ".")
            git(root, "-c", "user.name=CI", "-c", "user.email=ci@example.invalid",
                "commit", "-qm", "before")
            before = git(root, "rev-parse", "HEAD")
            (root / "docs").mkdir()
            initial.rename(root / "docs" / "renamed.sql")
            git(root, "add", "-A")
            git(root, "-c", "user.name=CI", "-c", "user.email=ci@example.invalid",
                "commit", "-qm", "after")
            after = git(root, "rev-parse", "HEAD")
            previous = Path.cwd()
            try:
                os.chdir(root)
                paths = ci.changed_paths(before, after)
            finally:
                os.chdir(previous)
            self.assertIn("savia/db/migrations/V999.sql", paths)
            self.assertIn("docs/renamed.sql", paths)
            self.assertTrue(ci.classify(paths)["requires_full"])

    def test_same_sha_and_empty_diff_are_not_valid_changes(self):
        with self.assertRaises(ValueError):
            ci.changed_paths("a" * 40, "a" * 40)

    def test_twenty_real_commit_path_samples_do_not_hide_critical_work(self):
        # One representative path for each of the 20 latest inspected Tony commits.
        # This is a regression oracle, NOT a complete impact-recall benchmark.
        cases = [
            ("savia/db/migrations/V030__catalog_recounts_and_business_kpis.sql", True, True),
            ("tests/golden-path/golden_path.py", True, True),
            ("savia/db/tests/sales/172_return_retry_safety.sql", True, True),
            ("savia/deploy/migrator/MigrationExecution.cs", True, True),
            (".github/workflows/golden-path.yml", True, True),
            ("docs/merge-readiness-20261116/corrections/STATUS.md", False, False),
            ("tools/bugproof/prove.py", True, True),
            ("docs/merge-readiness-20261116/pr5/probe.cjs", False, False),
            ("docs/branch-choice-20261107/build.py", False, False),
            ("savia/tools/verify.py", True, True),
            ("savia/web/screens/sale.mjs", True, True),
            ("savia/demo/api/index.mjs", True, True),
            ("savia/docs/research/staff-metrics-20261114/charts/verify.py", False, False),
            ("savia/docs/research/staff-metrics-20261114/decision.html", False, False),
            ("savia/docs/research/staff-metrics-20261114/decision.html", False, False),
            ("savia/docs/research/staff-metrics-20261114/mockup.html", False, False),
            ("savia/web/etiqueta/etiqueta.mjs", True, True),
            ("savia/db/migrations/V028__usd_change.sql", True, True),
            ("savia/docs/design/DOLARES.md", False, False),
            ("savia/src/Savia.Application/ForeignCash.cs", True, True),
        ]
        self.assertEqual(len(cases), 20)
        for path, critical, savia in cases:
            with self.subTest(path=path):
                result = ci.classify([path])
                self.assertEqual(result["requires_full"], critical)
                if savia:
                    self.assertTrue(result["run_savia"])

    def test_checkout_is_bound_to_actual_head(self):
        workflow = (SCRIPT.parents[1] / ".github/workflows/ci-strategy-pilot.yml").read_text(encoding="utf-8")
        self.assertIn("ref: ${{ github.event.pull_request.head.sha || github.sha }}", workflow)
        self.assertIn("git rev-parse HEAD", workflow)
        self.assertIn("tools/ci_strategy.py gate2-check", workflow)
        self.assertIn("permissions:\n  contents: read", workflow)
        self.assertNotIn("pull_request_target:", workflow)
        self.assertIn("  pull_request:\n    branches: [Tony, main]", workflow)
        self.assertNotIn("  push:\n", workflow)


class ReleaseHardening(unittest.TestCase):
    def test_trusted_api_audit_never_certifies_artifacts(self):
        sha = "a" * 40

        def get_json(path):
            if path == "/git/ref/heads/main":
                return {"object": {"sha": sha}}
            return {
                "total_count": len(ci.GATE3_CHECKS),
                "check_runs": [
                    {
                        "name": name, "status": "completed", "conclusion": "success",
                        "head_sha": sha, "app": {"slug": "github-actions"},
                    } for name in ci.GATE3_CHECKS
                ],
            }

        result = ci.audit_remote_main(sha, get_json)
        self.assertTrue(result["checks_verified"])
        self.assertFalse(result["release_allowed"])
        self.assertFalse(result["artifacts_verified"])

    def test_remote_stale_main_and_untrusted_checks_fail(self):
        sha = "a" * 40

        def get_json(path):
            if path == "/git/ref/heads/main":
                return {"object": {"sha": "b" * 40}}
            return {
                "total_count": 1,
                "check_runs": [{
                    "name": ci.GATE3_CHECKS[0], "status": "completed",
                    "conclusion": "skipped", "head_sha": sha, "app": None,
                }],
            }

        result = ci.audit_remote_main(sha, get_json)
        self.assertFalse(result["checks_verified"])
        self.assertTrue(result["errors"])

    def test_untrusted_positive_receipt_never_allows_release(self):
        sha = "a" * 40
        data = {
            "commit_sha": sha, "artifact_sha": sha, "branch": "main",
            "checks": [
                {"name": name, "head_sha": sha, "status": "completed", "conclusion": "success"}
                for name in ci.GATE3_CHECKS
            ],
            "review_approved": True, "rollback_drilled": True,
            "commercial_acceptance": True, "telemetry_ready": True,
            "sql_real_verified": True, "payment_sandbox_verified": True,
        }
        eligible, issues = ci.evaluate_release(data)
        self.assertFalse(eligible)
        self.assertIn(ci.RELEASE_BLOCKER, issues)


if __name__ == "__main__":
    unittest.main()
