"""Read the exact workflow predicate, not a copied 'policy' implementation."""
import ast
import itertools
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/bug-agent.yml"
BEGIN = "    if: >-\n"
END = "    runs-on:"


def live_predicate(enabled, actor, event, label, labels, approve):
    source = WORKFLOW.read_text(encoding="utf-8")
    block = source.split(BEGIN, 1)[1].split(END, 1)[0]
    expression = " ".join(line.strip() for line in block.splitlines())
    values = [
        ("contains(github.event.issue.labels.*.name, 'bug')", repr("bug" in labels)),
        ("vars.AI_BUG_AGENT_ENABLED", repr("true" if enabled else "false")),
        ("github.actor", repr(actor)),
        ("github.event_name", repr(event)),
        ("github.event.label.name", repr(label)),
        ("inputs.authorize_paid_agent", repr(approve)),
    ]
    for name, value in values:
        expression = expression.replace(name, value)
    expression = expression.replace("&&", " and ").replace("||", " or ")
    # GitHub Actions booleans are lowercase; preserve the quoted string value of the enable flag.
    expression = expression.replace("== true", "== True").replace("== false", "== False")
    tree = ast.parse(expression, mode="eval")
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Compare,
               ast.Eq, ast.Constant, ast.Load)
    unexpected = {type(node).__name__ for node in ast.walk(tree) if not isinstance(node, allowed)}
    if unexpected:
        raise AssertionError("Unrecognized workflow node types: " + ", ".join(sorted(unexpected)))
    return bool(eval(compile(tree, "<agent-workflow>", "eval"), {"__builtins__": {}}, {}))


class AgentAuthorization(unittest.TestCase):
    def test_all_combinations_require_specific_opt_in(self):
        count = 0
        for enabled, actor, event, label, has_bug, approve in itertools.product(
            (False, True), ("Suazo-AI", "other-user"),
            ("workflow_dispatch", "issues"), ("bug", "agent-approved"),
            (False, True), (False, True)
        ):
            with self.subTest(enabled=enabled, actor=actor, event=event, label=label,
                              bug=has_bug, approve=approve):
                actual = live_predicate(enabled, actor, event, label,
                                        ["bug"] if has_bug else [], approve)
                expected = enabled and actor == "Suazo-AI" and (
                    (event == "workflow_dispatch" and approve) or
                    (event == "issues" and label == "agent-approved" and has_bug)
                )
                self.assertEqual(actual, expected)
                count += 1
        self.assertEqual(count, 64)

    def test_agent_action_uses_approved_label_and_no_new_secrets(self):
        source = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("label_trigger: agent-approved", source)
        self.assertIn("authorize_paid_agent:", source)
        self.assertIn("vars.AI_BUG_AGENT_ENABLED == 'true'", source)
        self.assertIn("github.actor == 'Suazo-AI'", source)
        self.assertIn("persist-credentials: false", source)
        self.assertNotIn("pull_request_target:", source)


if __name__ == "__main__":
    unittest.main()
