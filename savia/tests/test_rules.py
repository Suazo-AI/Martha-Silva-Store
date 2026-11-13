"""Each rule of savia/tools/rules.py must fail on a bad tree and pass on a good one.

  python -m unittest discover -s savia/tests -p "test_rules.py"
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import rules  # noqa: E402

GOOD = {
    "db/migrations/V001__a.sql": "CREATE TABLE a(Id int);\n",
    "web/api.mjs": "export const sale = id => request('GET', path`/sales/${id}`);\nconst r = await fetch(BASE + '/reports/x.csv');\n",
    "web/confirm.mjs": "export const confirmAction = s => openModal(s); // never window.confirm(s)\n",
    "web/money.mjs": "export const cents = n => n * 100;\n",
    "web/screens/sale-logic.mjs": "import { cents } from '../money.mjs';\nexport const total = n => cents(n);\n",
    "web/screens/sale.mjs": "import * as api from '../api.mjs';\ndocument.title = 'Venta';\n",
    "web/tests/sale.test.mjs": "test('total', () => {});\n",
    "src/Savia.Api/Endpoints.cs": 'api.MapGet("/sales/{saleId:guid}", x);\napi.MapGet("/reports/x.csv", x);\n',
    "src/Savia.Application/Sales.cs": "using Savia.Contracts;\nusing Savia.Domain;\n",
    "src/Savia.Contracts/Sale.cs": "namespace Savia.Contracts;\n",
    "src/Savia.Domain/Roles.cs": "namespace Savia.Domain;\n",
    "tests/Savia.Tests/SaleTests.cs": "[Fact] public void Sells() {}\n",
}


class RulesTest(unittest.TestCase):
    def tree(self, changes=None):
        root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        for rel, text in {**GOOD, **(changes or {})}.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="")
        return root

    def broken(self, rule, changes, expect):
        found = rule(self.tree(changes))
        self.assertTrue(any(expect in item for item in found), f"{rule.__name__} missed it: {found}")

    def test_good_tree_passes_every_rule(self):
        root = self.tree()
        self.assertEqual(rules.accept_migrations(root), ["V001__a.sql"])
        for rule in rules.RULES:
            self.assertEqual(rule(root), [], rule.__name__)

    def test_migrations(self):
        root = self.tree()
        self.assertIn("not in", rules.migrations_are_frozen(root)[0])
        rules.accept_migrations(root)
        (root / "db/migrations/V001__a.sql").write_bytes(b"CREATE TABLE a(Id int);\r\n")
        self.assertEqual(rules.migrations_are_frozen(root), [], "line endings alone are not an edit")
        (root / "db/migrations/V001__a.sql").write_text("CREATE TABLE a(Id bigint);\n", encoding="utf-8")
        self.assertIn("was edited", rules.migrations_are_frozen(root)[0])
        self.assertEqual(rules.accept_migrations(root), [], "accept never rewrites a recorded entry")
        self.assertIn("was edited", rules.migrations_are_frozen(root)[0])
        (root / "db/migrations/V001__a.sql").unlink()
        self.assertIn("is gone", rules.migrations_are_frozen(root)[0])

    def test_web_dialogs_and_http(self):
        self.broken(rules.web_dialogs_and_http, {"web/screens/sale.mjs": "if (confirm('ok')) go();\n"}, "sale.mjs:1: browser dialog")
        self.broken(rules.web_dialogs_and_http, {"web/screens/sale.mjs": "x;\nwindow.alert('no');\n"}, "sale.mjs:2: browser dialog")
        self.broken(rules.web_dialogs_and_http, {"web/screens/sale.mjs": "await fetch('/api/v1/sales');\n"}, "HTTP call outside")
        self.broken(rules.web_dialogs_and_http, {"web/screens/sale.mjs": "el.innerHTML = name;\n"}, "HTML built from text")

    def test_web_logic_is_pure(self):
        self.broken(rules.web_logic_is_pure, {"web/screens/sale-logic.mjs": "import { h } from '../ui.mjs';\n"}, "imports ../ui.mjs")
        self.broken(rules.web_logic_is_pure, {"web/screens/sale-logic.mjs": "export const t = () => document.title;\n"}, "touches the browser")
        self.assertEqual(rules.web_logic_is_pure(self.tree({"web/screens/sale-logic.mjs": "export const t = 'open the window';\n"})), [])

    def test_layers(self):
        self.broken(rules.layers_point_inward, {"src/Savia.Application/Sales.cs": "using Microsoft.Data.SqlClient;\n"}, "Savia.Application must not use")
        self.broken(rules.layers_point_inward, {"src/Savia.Domain/Roles.cs": "using Savia.Contracts;\n"}, "Savia.Domain must not use")
        self.broken(rules.layers_point_inward, {"src/Savia.Api/Endpoints.cs": "using Microsoft.Data.SqlClient;\n"}, "Savia.Api must not use")

    def test_web_calls_real_routes(self):
        query = {"web/api.mjs": "export const sale = id => request('GET', `/sales/${id}${q({ page, pageSize })}`);\n"}
        self.assertEqual(rules.web_calls_real_routes(self.tree(query)), [], "a query built with q() is not part of the route")
        self.broken(rules.web_calls_real_routes, {"web/api.mjs": "export const x = () => request('GET', `/sale${q({ page })}`);\n"}, "/sale is not mapped")
        self.broken(rules.web_calls_real_routes, {"web/api.mjs": "export const x = () => request('GET', '/sale');\n"}, "/sale is not mapped")
        self.broken(rules.web_calls_real_routes, {"web/api.mjs": "export const x = id => request('POST', path`/sales/${id}/void`);\n"}, "/sales/{}/void is not mapped")

    def test_no_disabled_tests(self):
        self.broken(rules.no_disabled_tests, {"tests/Savia.Tests/SaleTests.cs": '[Fact(Skip = "flaky")] public void Sells() {}\n'}, "disabled test")
        self.broken(rules.no_disabled_tests, {"web/tests/sale.test.mjs": "test.skip('total', () => {});\n"}, "disabled test")
        self.broken(rules.no_disabled_tests, {"tests/test_x.py": "@unittest.skip('later')\ndef test_x(): pass\n"}, "disabled test")
        platform = {"tests/test_x.py": "@unittest.skipUnless(os.name == 'nt', 'Windows only')\ndef test_x(): pass\n"}
        self.assertEqual(rules.no_disabled_tests(self.tree(platform)), [])

    def test_guards_use_named_role_sets(self):
        app = "src/Savia.Application/Sales.cs"
        self.broken(rules.guards_use_named_role_sets, {app: "x;\nGuard.Role(actor, Roles.Manager, Roles.Owner);\n"}, "Sales.cs:2: guard spells its roles")
        self.broken(rules.guards_use_named_role_sets, {app: 'var b = Guard.BranchRole(actor, node, "OWNER");\n'}, "Sales.cs:1: guard spells its roles")
        self.broken(rules.guards_use_named_role_sets, {app: "f(Guard.BranchRole(actor, node, [Roles.Owner]), ct);\n"}, "guard spells its roles")
        self.broken(rules.guards_use_named_role_sets, {app: "Guard.Role(actor,\n    Roles.Seller,\n    Roles.Owner);\n"}, "Sales.cs:1: guard spells")
        self.broken(rules.guards_use_named_role_sets, {app: "private static readonly string[] Sellers = [Roles.Cashier, Roles.Owner];\n"}, "role list outside")
        named = {app: "var branch = Guard.BranchRole(actor, node, Roles.TillOperators);\nGuard.Role(approval, Roles.Approvers);\n",
                 "src/Savia.Domain/Roles.cs": "public static readonly string[] Approvers = [Manager, Owner];\n"}
        self.assertEqual(rules.guards_use_named_role_sets(self.tree(named)), [])

    def test_source_stays_readable(self):
        app = "src/Savia.Application/Sales.cs"
        self.broken(rules.source_stays_readable, {app: "x;\n" * 301}, "Sales.cs:301: 301 lines")
        self.broken(rules.source_stays_readable, {app: "x;\n" + "y" * 161 + "\n"}, "Sales.cs:2: 161 characters")
        self.assertEqual(rules.source_stays_readable(self.tree({app: ("y" * 160 + "\n") * 300})), [])
        self.assertEqual(rules.source_stays_readable(self.tree({"src/Savia.Api/obj/Generated.cs": "y" * 500 + "\n"})), [], "build output is not source")

    def test_no_pilot_names(self):
        self.broken(rules.no_pilot_names, {"src/Savia.Api/OwnerPilotEndpoints.cs": "namespace Savia.Api;\n"}, "OwnerPilotEndpoints.cs:1: file name")
        self.broken(rules.no_pilot_names, {"src/Savia.Application/Sales.cs": "x;\npublic sealed class PilotSalesService(IStore s)\n"}, "Sales.cs:2: type PilotSalesService")
        self.broken(rules.no_pilot_names, {"src/Savia.Application/Sales.cs": "public interface IPilotSalesStore\n"}, "type IPilotSalesStore")
        allowed = {"src/Savia.Application/Sales.cs": 'var on = config["Savia:Pilot:LocalCatalog"];   // the pilot class of 2026\n'}
        self.assertEqual(rules.no_pilot_names(self.tree(allowed)), [])


if __name__ == "__main__":
    unittest.main()
