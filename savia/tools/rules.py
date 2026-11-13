#!/usr/bin/env python3
"""Architecture rules of SAVIA v2 as checks. A broken rule prints file:line and what to do instead.

  python savia/tools/rules.py                      # check every rule
  python savia/tools/rules.py --accept-migrations  # record NEW migrations in the manifest (never rewrites an entry)
  python savia/tools/rules.py --root <savia dir>   # check another checkout

Each rule is a function (root) -> list of "path:line: message". Add a rule: write the function, add it to RULES,
add one failing case to savia/tests/test_rules.py.
"""
import hashlib
import re
import sys
from pathlib import Path

MANIFEST = "db/migrations/MANIFEST.sha256"
WEB_SKIP = ("vendor/", "tests/", ".test.mjs", "scanner-test.html")
PURE_WEB = re.compile(r"(-logic|/money|/roles)\.mjs$")
IMPURE = re.compile(r"\b(document|window|localStorage|sessionStorage|fetch|navigator)\b")
LAYERS = {  # project -> text that must not appear in its code
    "Savia.Domain": ("using Savia.", "Microsoft.Data.SqlClient", "Microsoft.AspNetCore"),
    "Savia.Contracts": ("using Savia.", "Microsoft.Data.SqlClient", "Microsoft.AspNetCore"),
    "Savia.Application": ("using Savia.Infrastructure", "using Savia.Api", "Microsoft.Data.SqlClient", "Microsoft.AspNetCore"),
    "Savia.Api": ("Microsoft.Data.SqlClient",),
}


def lines(path):
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def code(line, marker="//"):
    """The line without its trailing comment (good enough for these checks; URLs keep their //)."""
    cut = re.search(r"(?<![:'\"`])" + re.escape(marker), line)
    return line[:cut.start()] if cut else line


def web_files(root, suffixes=(".mjs", ".html")):
    for path in sorted((root / "web").rglob("*")):
        rel = path.relative_to(root).as_posix()
        if path.suffix in suffixes and not any(skip in rel for skip in WEB_SKIP):
            yield path, rel


def digest(path):
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def manifest(root):
    path = root / MANIFEST
    if not path.exists():
        return {}
    return {name: value for value, name in (row.split() for row in lines(path) if row.strip())}


def migrations_are_frozen(root):
    """A recorded migration never changes: write a new V0NN file instead."""
    known, out = manifest(root), []
    for path in sorted((root / "db/migrations").glob("V*.sql")):
        rel = f"db/migrations/{path.name}"
        if path.name not in known:
            out.append(f"{rel}:1: new migration is not in {MANIFEST}; run: python savia/tools/rules.py --accept-migrations")
        elif known[path.name] != digest(path):
            out.append(f"{rel}:1: a recorded migration was edited; restore it and put the change in a new V0NN file")
    present = {path.name for path in (root / "db/migrations").glob("V*.sql")}
    out += [f"{MANIFEST}:1: {name} is recorded but the file is gone; restore it" for name in sorted(set(known) - present)]
    return out


def accept_migrations(root):
    known = manifest(root)
    new = [p for p in sorted((root / "db/migrations").glob("V*.sql")) if p.name not in known]
    with (root / MANIFEST).open("a", encoding="utf-8", newline="\n") as out:
        for path in new:
            out.write(f"{digest(path)}  {path.name}\n")
    return [path.name for path in new]


def web_dialogs_and_http(root):
    """In-page confirmation only (web/confirm.mjs); every HTTP call lives in web/api.mjs."""
    out = []
    for path, rel in web_files(root):
        for number, line in enumerate(lines(path), 1):
            text = code(line)
            if re.search(r"(?<![\w.])(?:window\.)?(confirm|alert|prompt)\(", text):
                out.append(f"{rel}:{number}: browser dialog; use confirmAction from web/confirm.mjs or showError from web/ui.mjs")
            if re.search(r"(?<![\w.])fetch\(", text) and rel != "web/api.mjs":
                out.append(f"{rel}:{number}: HTTP call outside web/api.mjs; add a function there and call it")
            if re.search(r"\.(innerHTML|outerHTML)\s*=|insertAdjacentHTML\(", text):
                out.append(f"{rel}:{number}: HTML built from text; build nodes with h() from web/ui.mjs")
    return out


def web_logic_is_pure(root):
    """*-logic.mjs, money.mjs and roles.mjs run in node tests: no DOM, no storage, no HTTP, no impure import."""
    out = []
    for path, rel in web_files(root, (".mjs",)):
        if not PURE_WEB.search("/" + rel):
            continue
        for number, line in enumerate(lines(path), 1):
            text = code(line)
            imported = re.search(r"from\s+['\"]([^'\"]+)['\"]", text)
            if imported and not PURE_WEB.search("/" + imported.group(1).lstrip("./")):
                out.append(f"{rel}:{number}: pure module imports {imported.group(1)}; move the DOM or HTTP part to the screen")
            elif not imported and IMPURE.search(re.sub(r"(['\"`]).*?\1", "", text)):
                out.append(f"{rel}:{number}: pure module touches the browser; move that part to the screen")
    return out


def layers_point_inward(root):
    """Domain and Contracts know nothing; Application knows no SQL and no HTTP; only Infrastructure talks to SQL."""
    out = []
    for project, banned in LAYERS.items():
        for path in sorted((root / "src" / project).rglob("*.cs")):
            rel = path.relative_to(root).as_posix()
            if "/obj/" in rel or "/bin/" in rel:
                continue
            for number, line in enumerate(lines(path), 1):
                hit = next((b for b in banned if b in code(line) and not code(line).strip().startswith(f"using {project}")), None)
                if hit and not (project == "Savia.Contracts" and "using Savia.Contracts" in line):
                    out.append(f"{rel}:{number}: {project} must not use '{hit}'; put this code in the layer that owns it")
    return out


def route(text):
    return re.sub(r"\{[^}]*\}|\$\{[^}]*\}", "{}", text.split("?")[0]).rstrip("/")


def web_calls_real_routes(root):
    """Every path web/api.mjs calls is mapped by the API (Savia.Api/*.cs)."""
    mapped = set()
    for path in (root / "src/Savia.Api").glob("*.cs"):
        mapped |= {route(m) for m in re.findall(r"\.Map(?:Get|Post|Put|Delete)\(\s*\"([^\"]+)\"", path.read_text(encoding="utf-8"))}
    out = []
    api = root / "web/api.mjs"
    for number, line in enumerate(lines(api) if api.exists() else [], 1):
        if not re.search(r"request\(|exportReport\(|BASE \+", line):
            continue
        for called in re.findall(r"(?:path`|['`])(/[a-z][^'`]*)['`]", code(line)):
            if route(called) not in mapped:
                out.append(f"web/api.mjs:{number}: {route(called)} is not mapped in src/Savia.Api; fix the path or add the endpoint")
    return out


def no_disabled_tests(root):
    """A failing test is fixed or deleted with a reason, never skipped. A platform condition (skipUnless) is allowed."""
    patterns = {".cs": r"Skip\s*=", ".mjs": r"\b(test|it|describe)\.(skip|only|todo)\(", ".py": r"@unittest\.skip\(|@unittest\.skipIf\(True|pytest\.mark\.skip(?!if)"}
    out = []
    for folder in ("tests", "web", "tools"):
        for path in sorted((root / folder).rglob("*")):
            rel = path.relative_to(root).as_posix()
            if path.suffix in patterns and "vendor/" not in rel and "/obj/" not in rel and rel != "tools/rules.py":
                out += [f"{rel}:{n}: disabled test; fix it or delete it with the reason in the commit"
                        for n, line in enumerate(lines(path), 1) if re.search(patterns[path.suffix], line)]
    return out


RULES = [migrations_are_frozen, web_dialogs_and_http, web_logic_is_pure, layers_point_inward, web_calls_real_routes, no_disabled_tests]


def main(argv):
    root = Path(argv[argv.index("--root") + 1]).resolve() if "--root" in argv else Path(__file__).resolve().parents[1]
    if "--accept-migrations" in argv:
        print("recorded: " + (", ".join(accept_migrations(root)) or "nothing new"))
    failed = 0
    for rule in RULES:
        found = rule(root)
        failed += bool(found)
        print(f"{'FAIL' if found else 'PASS'}  {rule.__name__.replace('_', ' ')}" + ("" if found else f"  ({rule.__doc__.strip()})"))
        for item in found:
            print("      " + item)
    print(f"RULES {'FAIL' if failed else 'PASS'}: {len(RULES) - failed} of {len(RULES)} rules hold")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
