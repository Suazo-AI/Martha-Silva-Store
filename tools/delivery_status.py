#!/usr/bin/env python3
"""Deterministic delivery status for every push and pull request.

The ledger (docs/pipeline/ledger.json) is the single source of truth for where the project is.
This script validates it (fails closed on dishonest states) and renders a Markdown digest that
says what changed in this event, which gates it touched, what is next for each person, which
decisions and tools are still missing, and the critical path to production. An optional AI
narrator may comment on the digest, but it never replaces it: only this file decides status.

Standard library only, so it runs the same on a laptop, SUAZO-PC and GitHub Actions.
"""
import argparse
import fnmatch
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LEDGER = ROOT / 'docs' / 'pipeline' / 'ledger.json'
STATUSES = ('todo', 'doing', 'review', 'blocked', 'done', 'dropped')
OPEN = ('todo', 'doing', 'review', 'blocked')
SATISFIED = ('done', 'dropped')
REQUIRED = ('id', 'title', 'track', 'owner', 'status', 'why', 'done_when')
PR_SECTIONS = ('por que', 'alternativas', 'evidencia', 'que falta')
MARKER = '<!-- savia-progress-digest -->'
ZERO_SHA = '0' * 40
SHA = re.compile(r'^[0-9a-f]{7,40}$')


def fold(text):
    """Lowercase without accents, so '¿Por qué?' matches 'por que'."""
    text = unicodedata.normalize('NFKD', text or '')
    return ''.join(c for c in text if not unicodedata.combining(c)).lower()


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def validate(ledger):
    """Return a list of human-readable errors. An empty list means the ledger is honest."""
    errors = []
    tracks = {t['id'] for t in ledger.get('tracks', [])}
    people = set(ledger.get('people', {}))
    items = ledger.get('items', [])
    by_id = {}
    for index, item in enumerate(items):
        label = item.get('id', f'#{index}')
        missing = [field for field in REQUIRED if not str(item.get(field, '')).strip()]
        if missing:
            errors.append(f'{label}: missing {", ".join(missing)}')
        if label in by_id:
            errors.append(f'{label}: duplicate id')
        by_id[label] = item
        if item.get('status') not in STATUSES:
            errors.append(f'{label}: status must be one of {", ".join(STATUSES)}')
        if item.get('track') not in tracks:
            errors.append(f'{label}: unknown track {item.get("track")!r}')
        for owner in str(item.get('owner', '')).split('+'):
            if owner.strip() and owner.strip() not in people:
                errors.append(f'{label}: unknown owner {owner.strip()!r}')
        if item.get('status') == 'done' and not item.get('evidence'):
            errors.append(f'{label}: done without evidence')
        if item.get('status') == 'blocked' and not (item.get('blocked_by') or item.get('blocker')):
            errors.append(f'{label}: blocked without blocked_by or blocker')
        if item.get('status') == 'dropped' and not item.get('decision_ref'):
            errors.append(f'{label}: dropped without decision_ref')
    for label, item in by_id.items():
        for dep in item.get('blocked_by', []):
            if dep not in by_id:
                errors.append(f'{label}: blocked_by unknown {dep}')
            elif item.get('status') == 'done' and by_id[dep].get('status') not in SATISFIED:
                errors.append(f'{label}: done while prerequisite {dep} is {by_id[dep].get("status")}')
    for target in ledger.get('targets', []):
        if target.get('id') not in by_id:
            errors.append(f'target unknown {target.get("id")}')
    errors.extend(_cycles(by_id))
    return errors


def _cycles(by_id):
    state, errors = {}, []

    def visit(node, trail):
        if state.get(node) == 'done' or node not in by_id:
            return
        if state.get(node) == 'active':
            errors.append('dependency cycle: ' + ' -> '.join(trail[trail.index(node):] + [node]))
            return
        state[node] = 'active'
        for dep in by_id[node].get('blocked_by', []):
            visit(dep, trail + [node])
        state[node] = 'done'

    for node in by_id:
        visit(node, [])
    return errors


def actionable(ledger):
    """Open items whose prerequisites are done or deliberately dropped, grouped by owner."""
    by_id = {i['id']: i for i in ledger['items']}
    result = {}
    for item in ledger['items']:
        if item['status'] not in OPEN:
            continue
        if all(by_id.get(d, {}).get('status') in SATISFIED for d in item.get('blocked_by', [])):
            for owner in item['owner'].split('+'):
                result.setdefault(owner.strip(), []).append(item)
    return result


def critical_path(ledger, target):
    """Longest unfinished chain; raise ValueError for unknown nodes or cyclic ancestry."""
    by_id = {i['id']: i for i in ledger['items']}
    if target not in by_id:
        raise ValueError(f'unknown target {target}')
    memo = {}
    visiting = set()

    def chain(node):
        if node not in by_id:
            raise ValueError(f'unknown dependency {node}')
        if node in visiting:
            raise ValueError(f'dependency cycle at {node}')
        if node in memo:
            return memo[node]
        item = by_id[node]
        visiting.add(node)
        # Inspect even satisfied ancestry: invalid references must not look complete.
        paths = [chain(d) for d in item.get('blocked_by', [])]
        visiting.remove(node)
        best = max(paths, key=len, default=[])
        memo[node] = [] if item['status'] in SATISFIED else best + [node]
        return memo[node]

    return chain(target)


def touched(ledger, files):
    """Map changed files to the ledger items whose `paths` globs they match."""
    hits = {}
    for item in ledger['items']:
        for pattern in item.get('paths', []):
            matched = [f for f in files if fnmatch.fnmatch(f, pattern)]
            if matched:
                hits.setdefault(item['id'], set()).update(matched)
    return {k: sorted(v) for k, v in hits.items()}


def pr_sections_missing(body):
    headings = [fold(m) for m in re.findall(r'^#{2,4}\s*(.+?)\s*$', body or '', re.M)]
    return [s for s in PR_SECTIONS if not any(s in h for h in headings)]


def git(*args):
    out = subprocess.run(['git', *args], cwd=ROOT, capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 else ''


def is_commit(sha):
    return bool(sha) and sha != ZERO_SHA and bool(SHA.match(sha)) and subprocess.run(
        ['git', 'cat-file', '-e', sha + '^{commit}'], cwd=ROOT, capture_output=True).returncode == 0


def event_changes(base, head):
    """Commits and files between base and head; tolerant of new branches, force pushes and shallow clones."""
    if not is_commit(head):
        return [], []
    if is_commit(base):
        log_range, diff_args = [f'{base}..{head}'], [f'{base}...{head}']
    elif is_commit(head + '~1'):
        log_range, diff_args = [f'{head}~1..{head}'], [f'{head}~1', head]
    else:
        log_range, diff_args = [head, '-1'], ['--root', head]
    log = git('log', '--no-merges', '--format=%h%x09%an%x09%s', *log_range)
    commits = [line.split('\t', 2) for line in log.splitlines() if line.count('\t') >= 2]
    if diff_args[0] == '--root':
        files = git('show', '--name-only', '--format=', head).splitlines()
    else:
        files = git('diff', '--name-only', *diff_args).splitlines()
    return commits, [f for f in files if f]


def _cell(text):
    return str(text).replace('|', '\\|').replace('\n', ' ')


def render(ledger, errors, event):
    by_id = {i['id']: i for i in ledger['items']}
    people = ledger.get('people', {})
    out = [MARKER, f'## Estado de entrega · {event.get("title", "evento")}', '']
    if errors:
        out += ['> [!CAUTION]', '> El ledger no es coherente; este estado no es confiable hasta corregirlo:']
        out += [f'> - {_cell(e)}' for e in errors] + ['']
    for warning in event.get('warnings', []):
        out += [f'> [!WARNING]\n> {warning}', '']

    commits, files = event.get('commits', []), event.get('files', [])
    if commits or event.get('ref'):
        out.append(f'**Evento:** `{event.get("kind", "?")}` en `{event.get("ref", "?")}` por {event.get("actor", "?")}'
                   + (f' · head `{event["head"][:12]}`' if event.get('head') else ''))
        for sha, author, subject in commits[:15]:
            out.append(f'- `{sha}` {_cell(subject)} — {_cell(author)}')
        if len(commits) > 15:
            out.append(f'- … y {len(commits) - 15} commits más')
        out.append('')
    hits = touched(ledger, files)
    if files:
        if hits:
            out.append('**Compuertas tocadas por este cambio:** ' + ', '.join(
                f'{k} ({by_id[k]["status"]})' for k in sorted(hits)))
        else:
            out.append('**Compuertas tocadas por este cambio:** ninguna mapeada (revisar `paths` del ledger).')
        if hits and 'docs/pipeline/ledger.json' not in files:
            out.append('> Este cambio toca compuertas pero no actualiza `docs/pipeline/ledger.json`. '
                       'Si avanzó un estado, regístrelo con evidencia.')
        out.append('')

    out += ['### Dónde vamos', '', '| Carril | Hecho | En curso | Bloqueado | Pendiente |', '| --- | --- | --- | --- | --- |']
    for track in ledger['tracks']:
        items = [i for i in ledger['items'] if i['track'] == track['id'] and i['status'] != 'dropped']
        count = lambda *s: sum(i['status'] in s for i in items)  # noqa: E731
        out.append(f'| {_cell(track["name"])} | {count("done")}/{len(items)} | {count("doing", "review")} '
                   f'| {count("blocked")} | {count("todo")} |')
    out.append('')

    for target in ledger.get('targets', []):
        label = _cell(target['name'])
        try:
            path = critical_path(ledger, target['id'])
        except ValueError as error:
            out.append(f'**Camino crítico a {label}:** no disponible '
                       f'(ledger inválido: {_cell(error)}).')
            continue
        if not path:
            out.append(f'**Camino crítico a {label}:** completo.')
        else:
            out.append(f'**Camino crítico a {label}** ({len(path)} pasos): ' + ' → '.join(
                f'{p} [{by_id[p]["owner"]}]' for p in path))
    out.append('')

    out += ['### Siguiente acción por persona', '']
    for owner, items in sorted(actionable(ledger).items()):
        name = people.get(owner, owner)
        first = sorted(items, key=lambda i: (i['status'] != 'doing', i.get('order', 99)))
        out.append(f'- **{_cell(name)}:** ' + '; '.join(f'{i["id"]} {_cell(i["title"])} ({i["status"]})' for i in first[:3]))
    out.append('')

    decisions = [i for i in ledger['items'] if i['status'] in OPEN and i.get('needs', {}).get('decision')]
    if decisions:
        out += ['### Decisiones que faltan', '', '| Item | Quién decide | Decisión | Recomendación |', '| --- | --- | --- | --- |']
        for i in decisions:
            need = i['needs']
            out.append(f'| {i["id"]} | {_cell(people.get(need.get("decider", i["owner"]), need.get("decider", i["owner"])))} '
                       f'| {_cell(need["decision"])} | {_cell(need.get("recommendation", "—"))} |')
        out.append('')

    tools = [i for i in ledger['items'] if i['status'] in OPEN and (i.get('needs', {}).get('tool') or i.get('needs', {}).get('test'))]
    if tools:
        out += ['### Herramientas y pruebas que faltan', '']
        for i in tools:
            need = i['needs']
            parts = [f'herramienta: {need["tool"]}' if need.get('tool') else '', f'prueba: {need["test"]}' if need.get('test') else '']
            out.append(f'- **{i["id"]}** ' + ' · '.join(_cell(p) for p in parts if p))
        out.append('')

    blocked = [i for i in ledger['items'] if i['status'] == 'blocked']
    if blocked:
        out += ['### Bloqueos', '']
        for i in blocked:
            why = i.get('blocker') or 'espera ' + ', '.join(i.get('blocked_by', []))
            out.append(f'- **{i["id"]}** {_cell(i["title"])}: {_cell(why)}'
                       + (f' · salida propuesta: {_cell(i["unblock"])}' if i.get('unblock') else ''))
        out.append('')

    if hits:
        out += ['<details><summary>Por qué y alternativas de las compuertas tocadas</summary>', '']
        for k in sorted(hits):
            i = by_id[k]
            out.append(f'- **{k} {_cell(i["title"])}** — por qué: {_cell(i["why"])}. '
                       f'Hecho cuando: {_cell(i["done_when"])}.'
                       + (f' Alternativas: {_cell(i["alternatives"])}.' if i.get('alternatives') else ''))
        out += ['', '</details>', '']

    out.append(f'_Fuente: `docs/pipeline/ledger.json` (actualizado {ledger.get("updated", "?")}). '
               'Generado por `tools/delivery_status.py`; es determinista y no es aceptación del negocio ni despliegue._')
    return '\n'.join(out) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--ledger', type=Path, default=DEFAULT_LEDGER)
    parser.add_argument('--check', action='store_true', help='only validate; exit 1 on errors')
    parser.add_argument('--event', type=Path, help='GitHub event JSON ($GITHUB_EVENT_PATH)')
    parser.add_argument('--event-name', default='')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--require-pr-sections', action='store_true',
                        help='fail when a non-draft PR body lacks Por qué / Alternativas / Evidencia / Qué falta')
    args = parser.parse_args(argv)

    ledger = load(args.ledger)
    errors = validate(ledger)
    if args.check:
        for error in errors:
            print(f'ERROR: {error}')
        print(f'Ledger: {"invalid" if errors else "valid"}; {len(ledger.get("items", []))} items.')
        return 1 if errors else 0

    payload = load(args.event) if args.event and args.event.exists() else {}
    event = {'kind': args.event_name or 'manual', 'warnings': []}
    pr_failure = False
    if 'pull_request' in payload:
        pr = payload['pull_request']
        event.update(title=f'PR #{pr["number"]} {pr.get("title", "")}', ref=pr['head']['ref'],
                     actor=pr['user']['login'], head=pr['head']['sha'], base=pr['base']['sha'])
        missing = pr_sections_missing(pr.get('body'))
        if missing:
            event['warnings'].append('La descripción del PR no tiene las secciones: ' + ', '.join(missing)
                                     + '. Use `.github/pull_request_template.md`.')
            pr_failure = args.require_pr_sections and not pr.get('draft')
    elif payload.get('after'):
        ref = payload.get('ref', '').removeprefix('refs/heads/')
        event.update(title=f'push a {ref}', ref=ref, actor=(payload.get('pusher') or {}).get('name', '?'),
                     head=payload['after'], base=payload.get('before'))
    else:
        head = git('rev-parse', 'HEAD')
        event.update(title='estado actual', ref=git('rev-parse', '--abbrev-ref', 'HEAD'), actor='local', head=head)
    event['commits'], event['files'] = event_changes(event.get('base'), event.get('head'))

    text = render(ledger, errors, event)
    if args.output:
        args.output.write_text(text, encoding='utf-8')
    else:
        sys.stdout.write(text)
    return 1 if errors or pr_failure else 0


if __name__ == '__main__':
    sys.exit(main())
