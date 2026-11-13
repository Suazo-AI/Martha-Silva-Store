#!/usr/bin/env python3
"""Model checks of SAVIA designs with TLA+ (TLC). Every case of a small model is explored, not only tested ones.

  python savia/tools/formal.py setup    # download the pinned Java runtime and TLA+ tools into savia/.out/tools/formal
  python savia/tools/formal.py check    # run every check below; exit 1 when a result differs from the expected one
  python savia/tools/formal.py chart    # rewrite the Mermaid chart of the chosen design

A check that must FAIL is as important as one that must pass: it proves the rule can catch the mistake.
Models live in savia/formal/<name>/; read its README before changing the code it covers.
"""
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".out" / "tools" / "formal"
JAR = ("https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar",
       "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88")
JRE = ("https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.9%2B10/"
       "OpenJDK21U-jre_x64_windows_hotspot_21.0.9_10.zip",
       "39c5e23f3ce4d420663afba8ffde28034b72e2b3e240943dc2321bc1f912eef9", "jdk-21.0.9+10-jre")

RULES = ["TypeOK", "AnticipoResuelto", "ApartadaSoloConPedido", "VenceSoloSiLlego", "RespuestaYPrendaCoinciden",
         "NoSeNiegaLoQueViaja"]
CHOSEN = {"DiasApartado": 2, "RelojDesde": '"llegada"', "PlazoOrigen": 2, "PlazoLoCuenta": '"origen"', "Falla": '"ninguna"'}
# name, module folder, constants that differ from CHOSEN, expected result, why it matters
CHECKS = [
    ("diseno elegido", "apartado", {}, "pass", "las seis reglas y el plazo de origen se cumplen en todos los casos"),
    ("reloj desde el pedido", "apartado", {"RelojDesde": '"pedido"'}, "VenceSoloSiLlego",
     "si el plazo cuenta desde el pedido, el apartado puede vencer con la prenda todavia en camino"),
    ("sin plazo para origen", "apartado", {"PlazoOrigen": 0}, "NoEsperaAlOrigen",
     "sin plazo, un pedido puede esperar para siempre a que la tienda origen responda"),
    ("plazo contado en destino", "apartado", {"PlazoLoCuenta": '"destino"'}, "NoSeNiegaLoQueViaja",
     "si destino cierra por falta de respuesta, puede negarle al cliente una prenda que ya viene en camino"),
    ("falla sembrada: anticipo", "apartado", {"Falla": '"no_devuelve_anticipo"'}, "AnticipoResuelto",
     "la regla detecta un anticipo cobrado que nadie devuelve"),
    ("falla sembrada: prenda", "apartado", {"Falla": '"no_libera_prenda"'}, "ApartadaSoloConPedido",
     "la regla detecta una prenda apartada sin cliente"),
]


def fetch(url, sha, target):
    if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != sha:
        print(f"downloading {target.name}")
        with urllib.request.urlopen(url, timeout=300) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != sha:
            raise SystemExit(f"formal: {target.name} does not match its pinned SHA-256; nothing was installed")
        target.write_bytes(data)


def java():
    local = TOOLS / JRE[2] / "bin" / "java.exe"
    return str(local) if local.exists() else shutil.which("java")


def setup():
    TOOLS.mkdir(parents=True, exist_ok=True)
    fetch(*JAR, TOOLS / "tla2tools.jar")
    if java() is None:
        archive = TOOLS / "jre.zip"
        fetch(JRE[0], JRE[1], archive)
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(TOOLS)
        archive.unlink()
    version = subprocess.run([java(), "-version"], capture_output=True, text=True).stderr.splitlines()[0]
    print(f"formal: ready ({version}; TLA+ tools 1.7.4) in {TOOLS}")


def tlc(folder, constants, property_=True, dump=None):
    """Runs TLC on savia/formal/<folder>. Returns (broken rule or 'pass', action names of the counterexample)."""
    module = next((ROOT / "formal" / folder).glob("*.tla"))
    with tempfile.TemporaryDirectory() as work:
        config = Path(work) / "check.cfg"
        config.write_text("SPECIFICATION Spec\nCONSTANTS\n" + "".join(f"  {k} = {v}\n" for k, v in {**CHOSEN, **constants}.items())
                          + "INVARIANTS " + " ".join(RULES) + "\n" + ("PROPERTY NoEsperaAlOrigen\n" if property_ else ""), encoding="utf-8")
        command = [java(), "-XX:+UseParallelGC", "-cp", str(TOOLS / "tla2tools.jar"), "tlc2.TLC", "-config", str(config),
                   "-metadir", str(Path(work) / "states"), "-workers", "1"] + (["-dump", "dot,actionlabels", str(dump)] if dump else [])
        # TLC resolves -config against the module's folder when the module path is absolute, so pass the bare name.
        out = subprocess.run(command + [module.name], cwd=module.parent, capture_output=True, text=True, timeout=600).stdout
    path = re.findall(r"^State \d+: <(\w+)", out, re.M)
    broken = re.search(r"Error: Invariant (\w+) is violated", out)
    if broken:
        return broken.group(1), path
    if "Temporal properties were violated" in out:
        return "NoEsperaAlOrigen", path
    if "Deadlock reached" in out:
        return "deadlock", path
    if "No error has been found" in out:
        return "pass", []
    return "TLC error: " + " ".join(line.strip() for line in out.splitlines() if "rror" in line)[:300], []


def check():
    failed = 0
    for name, folder, constants, expected, why in CHECKS:
        got, path = tlc(folder, constants)
        ok = got == expected
        failed += not ok
        wanted = "holds" if expected == "pass" else f"breaks {expected}, as it must"
        print(f"{'PASS' if ok else 'FAIL'}  {name}: {wanted if ok else f'expected {expected}, got {got}'}  ({why})")
        if path and expected != "pass":
            print("      shortest path: " + ", ".join(path))
    print(f"FORMAL {'FAIL' if failed else 'PASS'}: {len(CHECKS) - failed} of {len(CHECKS)} checks gave the expected result")
    return 1 if failed else 0


def chart():
    """Every reachable state of the chosen design, seen as (pedido, prenda), as a Mermaid statechart."""
    with tempfile.TemporaryDirectory() as work:
        dot = Path(work) / "states.dot"
        got, _ = tlc("apartado", {}, property_=False, dump=dot)
        if got != "pass":
            raise SystemExit(f"formal: the chosen design does not hold ({got}); no chart written")
        text = dot.read_text(encoding="utf-8")
    view = {}
    for node, label in re.findall(r'^(-?\d+) \[label="(.*)"[\],]', text, re.M):
        values = dict(re.findall(r'(\w+) = \\"(\w+)\\"', label))
        view[node] = f"{values['pedido']}__{values['prenda']}"
    edges = sorted({(view[a], view[b], action) for a, b, action in re.findall(r'^(-?\d+) -> (-?\d+) \[label="(\w+)"', text, re.M)
                    if view[a] != view[b]})
    lines = ["stateDiagram-v2", "    [*] --> sin_pedido__en_venta_origen"]
    lines += [f"    {a} --> {b}: {action}" for a, b, action in edges]
    lines += [f"    {name}: {name.split('__')[0]} / {name.split('__')[1]}" for name in sorted(set(view.values()))]
    target = ROOT / "formal" / "apartado" / "chart.mmd"
    target.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"formal: {len(set(view.values()))} states, {len(edges)} moves -> {target}")
    return 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    if command == "setup":
        sys.exit(setup())
    if java() is None or not (TOOLS / "tla2tools.jar").exists():
        sys.exit("formal: tools are not installed; run: python savia/tools/formal.py setup")
    sys.exit(chart() if command == "chart" else check())
