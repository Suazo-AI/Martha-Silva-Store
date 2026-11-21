"""Offline business model. NOT SAVIA, SISFAIN, a fiscal engine, or a performance test.

Only Python standard library, memory, and explicit output files. No runtime/network access.
Run: python docs/synthetic-replacement-20261104/simulate.py --out <directory>
Money uses integer centavos. All people, SKUs and transactions are fictional.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path


def encoded(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()


class Rejected(Exception):
    pass


class Model:
    def __init__(self):
        self.state = {
            "items": {"MOCK-BLUSA-M": {"price": 35000, "stock": 8},
                      "MOCK-JEAN-30": {"price": 90000, "stock": 4},
                      "MOCK-VESTIDO-S": {"price": 120000, "stock": 0}},
            "sales": {}, "operations": {}, "audit": [], "receipts": {},
            "purchases": {}, "receivable": {}, "cash": 0, "transfer": 0,
        }

    def event(self, kind, actor, payload):
        previous = self.state["audit"][-1]["hash"] if self.state["audit"] else "0" * 64
        record = {"sequence": len(self.state["audit"]) + 1, "kind": kind,
                  "actor": actor, "payload": payload, "previous": previous}
        record["hash"] = hashlib.sha256(encoded(record)).hexdigest()
        self.state["audit"].append(record)

    def sale(self, key, lines, payments, actor="MOCK-CAJA-A", credit=False):
        fingerprint = hashlib.sha256(encoded([lines, payments, actor, credit])).hexdigest()
        if key in self.state["operations"]:
            previous = self.state["operations"][key]
            if previous["fingerprint"] != fingerprint:
                raise Rejected("idempotency_conflict")
            return copy.deepcopy(self.state["sales"][previous["sale"]])
        if actor not in ("MOCK-CAJA-A", "MOCK-CAJA-B"):
            raise Rejected("forbidden")
        if not lines or len({x["sku"] for x in lines}) != len(lines):
            raise Rejected("invalid_lines")
        calculated = []
        for line in lines:
            item = self.state["items"].get(line["sku"])
            qty = line["qty"]
            if item is None or type(qty) is not int or qty <= 0:
                raise Rejected("invalid_line")
            if item["stock"] < qty:
                raise Rejected("stock_difference_requires_reconciliation")
            calculated.append({**line, "price": item["price"], "returned": 0,
                               "total": qty * item["price"]})
        total = sum(x["total"] for x in calculated)
        if set(payments) - {"cash", "transfer"} or any(type(v) is not int or v < 0 for v in payments.values()):
            raise Rejected("invalid_payment")
        paid = sum(payments.values())
        if paid > total or (not credit and paid != total):
            raise Rejected("payment_mismatch")
        # All validations precede mutation: atomicity in this sequential model only.
        sale_id = f"MOCK-V{len(self.state['sales']) + 1:04d}"
        result = {"id": sale_id, "actor": actor, "lines": calculated, "total": total,
                  "payments": dict(payments), "balance": total - paid, "refund": 0,
                  "document": "SIMULADO-SIN-VALIDEZ-FISCAL"}
        for line in calculated:
            self.state["items"][line["sku"]]["stock"] -= line["qty"]
        for method, amount in payments.items():
            self.state[method] += amount
        self.state["sales"][sale_id] = result
        self.state["receivable"][sale_id] = total - paid
        self.state["operations"][key] = {"fingerprint": fingerprint, "sale": sale_id}
        self.event("sale", actor, {"id": sale_id, "key": key, "total": total})
        return copy.deepcopy(result)

    def reconcile(self, sku, observed, actor, reason, physical_reference):
        if actor != "MOCK-MANAGER" or not reason or not physical_reference:
            raise Rejected("authorization_or_reason_missing")
        if type(observed) is not int or observed < 0:
            raise Rejected("invalid_count")
        item = self.state["items"][sku]
        old = item["stock"]
        item["stock"] = observed
        self.event("physical_count_adjustment", actor, {"sku": sku, "before": old,
                   "after": observed, "delta": observed - old, "reason": reason,
                   "physical_reference": physical_reference})

    def return_line(self, key, sale_id, sku, qty):
        fingerprint = [sale_id, sku, qty]
        if key in self.state["receipts"]:
            previous = self.state["receipts"][key]
            if previous["fingerprint"] != fingerprint:
                raise Rejected("return_key_conflict")
            return previous["refund"]
        sale = self.state["sales"][sale_id]
        if sale["balance"] or sale["payments"].get("transfer", 0):
            raise Rejected("refund_route_not_modeled")
        line = next(x for x in sale["lines"] if x["sku"] == sku)
        if type(qty) is not int or qty <= 0 or line["returned"] + qty > line["qty"]:
            raise Rejected("over_return")
        amount = qty * line["price"]
        line["returned"] += qty
        sale["refund"] += amount
        self.state["items"][sku]["stock"] += qty
        self.state["cash"] -= amount
        self.state["receipts"][key] = {"fingerprint": fingerprint, "refund": amount}
        self.event("return", "MOCK-MANAGER", {"sale": sale_id, "sku": sku, "qty": qty, "refund": amount})
        return amount

    def purchase(self, purchase_id, sku, qty, unit_cost):
        if purchase_id in self.state["purchases"] or qty <= 0 or unit_cost < 0:
            raise Rejected("invalid_purchase")
        self.state["purchases"][purchase_id] = {"sku": sku, "ordered": qty, "received": 0,
                                                 "unit_cost": unit_cost}
        self.event("purchase", "MOCK-INVENTARIO", {"id": purchase_id, "qty": qty})

    def receive(self, key, purchase_id, qty):
        signature = [purchase_id, qty]
        if key in self.state["receipts"]:
            if self.state["receipts"][key] != signature:
                raise Rejected("receipt_key_conflict")
            return
        order = self.state["purchases"][purchase_id]
        if qty <= 0 or order["received"] + qty > order["ordered"]:
            raise Rejected("over_receive")
        order["received"] += qty
        self.state["items"][order["sku"]]["stock"] += qty
        self.state["receipts"][key] = signature
        self.event("receive", "MOCK-INVENTARIO", {"order": purchase_id, "qty": qty, "key": key})

    def collect(self, key, sale_id, amount):
        signature = [sale_id, amount]
        if key in self.state["receipts"]:
            if self.state["receipts"][key] != signature:
                raise Rejected("collection_key_conflict")
            return
        if amount <= 0 or amount > self.state["receivable"][sale_id]:
            raise Rejected("over_collection")
        self.state["receivable"][sale_id] -= amount
        self.state["sales"][sale_id]["balance"] -= amount
        self.state["cash"] += amount
        self.state["receipts"][key] = signature
        self.event("collection", "MOCK-CAJA-A", {"sale": sale_id, "amount": amount})

    def backup(self):
        body = copy.deepcopy(self.state)
        return {"body": body, "sha256": hashlib.sha256(encoded(body)).hexdigest()}

    @classmethod
    def restore(cls, backup):
        if hashlib.sha256(encoded(backup["body"])).hexdigest() != backup["sha256"]:
            raise Rejected("backup_integrity")
        model = cls()
        model.state = copy.deepcopy(backup["body"])
        return model


def run():
    results = []

    def check(case, title, initial, action, expected, evidence):
        if not all(evidence.values()):
            raise AssertionError(f"{case}: {evidence}")
        results.append(dict(id=case, title=title, initial=initial, action=action,
                            expected=expected, checks=evidence, status="PASS_MODELO"))

    def rejection(model, code, operation):
        before = encoded(model.state)
        try:
            operation()
        except Rejected as error:
            return {"expected_rejection": str(error) == code, "state_unchanged": encoded(model.state) == before}
        return {"expected_rejection": False, "state_unchanged": encoded(model.state) == before}

    model = Model()
    initial_fixture = copy.deepcopy(model.state)
    check("S01", "Conciliación por un rol sin permiso", "Vestido: registro 0; conteo ficticio 1.",
          "La caja intenta ajustar existencias; en esta propuesta solo Manager puede autorizar.",
          "Ajuste rechazado; ningún saldo, cobro o documento cambia. S02 prueba el camino autorizado.",
          rejection(model, "authorization_or_reason_missing", lambda: model.reconcile(
              "MOCK-VESTIDO-S", 1, "MOCK-CAJA-A", "conteo", "MOCK-CNT1")))
    model.reconcile("MOCK-VESTIDO-S", 1, "MOCK-MANAGER", "prenda encontrada en conteo", "MOCK-CNT1")
    # Another model covers the delivery after reconciliation; the first remains for the multi-item cart.
    zero = Model.restore(model.backup())
    z = zero.sale("MOCK-ZERO", [{"sku": "MOCK-VESTIDO-S", "qty": 1}], {"cash": 120000})
    check("S02", "Entrega tras conciliación", "Registro reconciliado a 1.", "Vender el vestido una vez.",
          "Saldo 0; ajuste visible; venta visible; sin inventar una compra.",
          {"stock_zero": zero.state["items"]["MOCK-VESTIDO-S"]["stock"] == 0,
           "sale_total": z["total"] == 120000,
           "adjustment_and_sale": [a["kind"] for a in zero.state["audit"]] == ["physical_count_adjustment", "sale"]})
    check("S03", "Sin prenda física", "Registro 0; conteo 0.", "Intentar otra venta del vestido.",
          "No se promete una entrega inexistente; no cambia caja ni inventario.",
          rejection(zero, "stock_difference_requires_reconciliation", lambda: zero.sale(
              "MOCK-NONE", [{"sku": "MOCK-VESTIDO-S", "qty": 1}], {"cash": 120000})))
    cart = [{"sku": "MOCK-BLUSA-M", "qty": 2}, {"sku": "MOCK-JEAN-30", "qty": 1},
            {"sku": "MOCK-VESTIDO-S", "qty": 1}]
    payments = {"cash": 100000, "transfer": 180000}
    sale = model.sale("MOCK-CART", cart, payments)
    check("S04", "Una factura, varios artículos", "Blusa 8, jean 4, vestido 1.",
          "2 blusas × C$350 + 1 jean × C$900 + 1 vestido × C$1.200; pago mixto.",
          "3 renglones, 4 prendas, total C$2.800; caja C$1.000 y transferencia C$1.800.",
          {"three_lines": len(sale["lines"]) == 3, "four_units": sum(x["qty"] for x in sale["lines"]) == 4,
           "total": sale["total"] == 280000, "cash": model.state["cash"] == 100000,
           "transfer": model.state["transfer"] == 180000,
           "stocks": [model.state["items"][x]["stock"] for x in model.state["items"]] == [6, 3, 0]})
    before = encoded(model.state)
    replay = model.sale("MOCK-CART", cart, payments)
    check("S05", "Respuesta perdida y doble clic", "La venta anterior se confirmó, pero la respuesta se pierde.",
          "Consultar/reintentar con la misma clave y contenido.", "Mismo identificador; una venta y un descuento de stock.",
          {"same_id": replay["id"] == sale["id"], "no_second_mutation": encoded(model.state) == before,
           "one_sale": len(model.state["sales"]) == 1})
    check("S06", "Clave reutilizada con otro cajero", "MOCK-CART pertenece a caja A.",
          "Reutilizar la clave desde caja B.", "Conflicto; ninguna venta, cobro o ajuste adicional.",
          rejection(model, "idempotency_conflict", lambda: model.sale("MOCK-CART", cart, payments, "MOCK-CAJA-B")))
    check("S07", "Un renglón inválido", "Hay blusas; el vestido ya no está.",
          "Enviar blusa y vestido juntos.", "Ningún renglón se guarda; no se cobra parcialmente.",
          rejection(model, "stock_difference_requires_reconciliation", lambda: model.sale(
              "MOCK-ATOMIC", [{"sku": "MOCK-BLUSA-M", "qty": 1}, {"sku": "MOCK-VESTIDO-S", "qty": 1}], {"cash": 155000})))
    check("S08", "Pago insuficiente", "Una blusa cuesta C$350.", "Intentar contado de C$349.",
          "Rechazo sin mutación; el crédito requiere un flujo explícito.", rejection(model, "payment_mismatch",
          lambda: model.sale("MOCK-SHORT", [{"sku": "MOCK-BLUSA-M", "qty": 1}], {"cash": 34900})))
    check("S09", "Rol sin permiso", "Usuario MOCK-LECTOR.", "Intentar registrar venta.", "Rechazo sin mutación.",
          rejection(model, "forbidden", lambda: model.sale("MOCK-DENY", [{"sku": "MOCK-BLUSA-M", "qty": 1}], {"cash": 35000}, "MOCK-LECTOR")))
    last = Model()
    last.reconcile("MOCK-BLUSA-M", 1, "MOCK-MANAGER", "conteo ficticio", "MOCK-CNT2")
    last.sale("MOCK-LAST-A", [{"sku": "MOCK-BLUSA-M", "qty": 1}], {"cash": 35000})
    evidence = rejection(last, "stock_difference_requires_reconciliation", lambda: last.sale(
        "MOCK-LAST-B", [{"sku": "MOCK-BLUSA-M", "qty": 1}], {"cash": 35000}, "MOCK-CAJA-B"))
    evidence["only_one_sale"] = len(last.state["sales"]) == 1
    check("S10", "Última unidad: orden A y luego B", "Dos cajas observan una unidad.",
          "Ejecutar A y B en secuencia; este modelo no usa hilos ni SQL.",
          "Solo A vende. Falta repetir la carrera concurrente en la aplicación real.", evidence)
    day = Model()
    day.purchase("MOCK-PO1", "MOCK-BLUSA-M", 5, 20000)
    day.receive("MOCK-RC1", "MOCK-PO1", 2)
    day.receive("MOCK-RC1", "MOCK-PO1", 2)
    check("S11", "Compra y recepción parcial", "8 blusas; orden de 5.", "Recibir 2 y repetir la confirmación.",
          "Stock 10; recibido 2, pendiente 3; repetir no duplica.",
          {"stock": day.state["items"]["MOCK-BLUSA-M"]["stock"] == 10,
           "received": day.state["purchases"]["MOCK-PO1"]["received"] == 2,
           **rejection(day, "over_receive", lambda: day.receive("MOCK-OVER", "MOCK-PO1", 4))})
    paid_sale = day.sale("MOCK-RETURN-SALE", [{"sku": "MOCK-BLUSA-M", "qty": 2}, {"sku": "MOCK-JEAN-30", "qty": 1}], {"cash": 160000})
    refund = day.return_line("MOCK-RET1", paid_sale["id"], "MOCK-BLUSA-M", 1)
    state_after_return = encoded(day.state)
    repeat_refund = day.return_line("MOCK-RET1", paid_sale["id"], "MOCK-BLUSA-M", 1)
    check("S12", "Devolución parcial rastreable", "Venta de 2 blusas y 1 jean.", "Devolver 1 blusa; repetir solicitud.",
          "Reintegro C$350 una vez, stock +1, original preservado; no devolver más de lo vendido.",
          {"refund": refund == repeat_refund == 35000, "replay_unchanged": encoded(day.state) == state_after_return,
           "cash": day.state["cash"] == 125000,
           **rejection(day, "over_return", lambda: day.return_line("MOCK-RET2", paid_sale["id"], "MOCK-BLUSA-M", 2))})
    credit = day.sale("MOCK-CREDIT", [{"sku": "MOCK-JEAN-30", "qty": 1}], {"cash": 30000}, credit=True)
    day.collect("MOCK-AB1", credit["id"], 20000)
    day.collect("MOCK-AB1", credit["id"], 20000)
    check("S13", "Crédito y abono", "Venta C$900, anticipo C$300.", "Abonar C$200 y repetir.",
          "Saldo C$400; un solo abono; cobro superior al saldo rechazado.",
          {"balance": day.state["receivable"][credit["id"]] == 40000,
           **rejection(day, "over_collection", lambda: day.collect("MOCK-AB2", credit["id"], 40100))})
    check("S14", "Cierre del día", "Ventas C$2.500, devolución C$350, saldo crédito C$400.",
          "Reconciliar cobrado y saldo; comparar conteo ficticio de caja.",
          "Caja C$1.750; un conteo de C$1.740 tiene diferencia -C$10 y requiere revisión.",
          {"cash": day.state["cash"] == 175000,
           "equation": 250000 - 35000 - 40000 == day.state["cash"],
           "difference_detected": 174000 - day.state["cash"] == -1000})
    backup = day.backup()
    restored = Model.restore(backup)
    replay_before = encoded(restored.state)
    restored.collect("MOCK-AB1", credit["id"], 20000)
    check("S15", "Respaldo y recuperación del modelo", "Snapshot del día con ventas, claves, saldos y bitácora.",
          "Serializar/restaurar y repetir abono anterior.",
          "Estado exacto, clave conservada, ningún abono duplicado. No prueba restore de SQL Server.",
          {"same_state": encoded(restored.state) == replay_before == encoded(day.state),
           "file_roundtrip": encoded(json.loads(json.dumps(backup))) == encoded(backup)})
    corrupted = copy.deepcopy(backup)
    corrupted["body"]["cash"] += 1
    try:
        Model.restore(corrupted)
        detected = False
    except Rejected as error:
        detected = str(error) == "backup_integrity"
    check("S16", "Respaldo alterado", "Snapshot cambia un centavo sin actualizar su hash.",
          "Intentar restauración.", "Integridad rechazada. El hash no autentica a un atacante que pueda recalcularlo.",
          {"tampering_detected": detected})
    batch = Model()
    batch.reconcile("MOCK-BLUSA-M", 40, "MOCK-MANAGER", "fixture de lote", "MOCK-CNT30")
    for i in range(30):
        batch.sale(f"MOCK-BATCH-{i}", [{"sku": "MOCK-BLUSA-M", "qty": 1}], {"cash": 35000})
    check("S17", "Treinta ventas ficticias", "Stock inicial 40; blusa C$350.", "Ejecutar 30 claves únicas.",
          "30 ventas, caja C$10.500, stock 10. No mide p50/p95, red, impresora ni caja real.",
          {"sales": len(batch.state["sales"]) == 30, "cash": batch.state["cash"] == 1050000,
           "stock": batch.state["items"]["MOCK-BLUSA-M"]["stock"] == 10})
    # Independent oracle values above are fixed arithmetic, not computed from model responses.
    # Deliberately corrupt copies: a green process must notice invalid business outcomes.
    mutations = []
    bad = copy.deepcopy(sale); bad["total"] = 279999
    mutations.append({"fault": "total_wrong_by_one_cent", "detected": bad["total"] != 280000})
    bad_stock = copy.deepcopy(model.state); bad_stock["items"]["MOCK-BLUSA-M"]["stock"] -= 2
    mutations.append({"fault": "duplicate_stock_decrement", "detected": bad_stock["items"]["MOCK-BLUSA-M"]["stock"] != 6})
    bad_cash = copy.deepcopy(day.state); bad_cash["cash"] += 20000
    mutations.append({"fault": "duplicate_collection", "detected": bad_cash["cash"] != 175000})
    check("S18", "El control debe detectar un resultado malo", "Copias con total, stock y abono alterados.",
          "Aplicar los mismos oráculos de negocio a resultados corruptos.",
          "Detectar las 3 alteraciones. Es un control negativo del modelo, no mutation testing del producto.",
          {m["fault"]: m["detected"] for m in mutations})
    acceptance = {"acceptor": "coordinador SUAZO-PC", "synthetic_model": "PASS",
                  "real_seller_5_tasks": "NOT_RUN", "real_checkout_30_measurements": "NOT_RUN",
                  "windows_sql_restore_C9": "BLOCKED_TLS", "fiscal_configuration": "UNKNOWN",
                  "trial_C10": "NOT_ACCEPTED", "production": "NOT_READY"}
    return {"kind": "SYNTHETIC_MODEL_ONLY", "currency": "NIO", "money_unit": "centavo",
            "tax": "not_modeled; no fiscal validity", "fixture": initial_fixture,
            "summary": {"scenarios": len(results), "passed": len(results),
                        "assertions": sum(len(x["checks"]) for x in results), "failed": 0,
                        "negative_controls_detected": len(mutations)},
            "scenarios": results, "negative_controls": mutations, "acceptance": acceptance,
            "day_end": day.state, "limitations": [
                "No SAVIA code, HTTP, SQL, Windows security, real transactions or SISFAIN exercised.",
                "Sequential model; no database concurrency or transactional isolation proof.",
                "No taxes, fiscal authorization, customer data, card processing, costing or supplier payments.",
                "A hash detects accidental alteration, not hostile rewriting or independent acceptance."]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    result = run()
    result["simulator_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    (args.out / "results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    template = Path(__file__).with_name("template.html")
    if template.exists():
        html = template.read_text(encoding="utf-8").replace("__RESULTS_JSON__", json.dumps(result, ensure_ascii=False).replace("<", "\\u003c"))
        (args.out / "index.html").write_text(html, encoding="utf-8")
    print(json.dumps(result["summary"]))
