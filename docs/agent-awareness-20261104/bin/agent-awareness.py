"""Read-only, bounded cross-harness awareness. A warning, never an edit lock."""
import argparse
from contextlib import contextmanager
import datetime as dt
import json
import ntpath
import os
import re
from pathlib import Path
import sqlite3
import subprocess
import sys
import time

HOME = Path.home()
PROCESS_QUERY = r"""$all = @(Get-CimInstance Win32_Process -ErrorAction Stop)
$byId = @{}; foreach ($p in $all) { $byId[[int]$p.ProcessId] = $p }
$rows = @($all | ForEach-Object {
  $name = $_.Name.ToLowerInvariant(); $kind = $null
  if ($name -eq 'codex.exe' -and $_.CommandLine -match 'app-server') { $kind = 'codex-server' }
  elseif ($name -eq 't3 code (beta).exe' -and $byId[[int]$_.ParentProcessId].Name -ne $_.Name) { $kind = 't3-app' }
  elseif ($name -in @('claude.exe','opencode.exe','agy.exe','agy_acp_server.exe')) {
    if ($byId[[int]$_.ParentProcessId].Name -ne $_.Name) { $kind = $name.Replace('.exe','') }
  }
  if ($kind) { [pscustomobject]@{ pid=[int]$_.ProcessId; parent_pid=[int]$_.ParentProcessId; kind=$kind } }
})
ConvertTo-Json -InputObject $rows -Compress
"""


def normalized(path):
    return ntpath.normcase(ntpath.normpath(str(path))).rstrip('\\')


def related(left, right):
    """Parent workspace and its checkout count as possibly overlapping."""
    if not left or not right:
        return False
    a, b = normalized(left), normalized(right)
    return a == b or a.startswith(b + '\\') or b.startswith(a + '\\')


@contextmanager
def read_db(path):
    connection = sqlite3.connect(path.resolve().as_uri() + '?mode=ro', uri=True, timeout=0.25)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute('PRAGMA query_only=ON')
        yield connection
    finally:
        connection.close()


def safe(value, maximum=260):
    return re.sub(r'[\x00-\x1f\x7f]', '?', str(value))[:maximum]


def model_name(value):
    return value if isinstance(value, str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._/-]{0,80}', value) else 'unknown'


def process_snapshot():
    result = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', PROCESS_QUERY],
                            capture_output=True, text=True, timeout=5, check=True)
    rows = json.loads(result.stdout or '[]')
    return rows if isinstance(rows, list) else [rows]


def t3_threads(path, workspace, live, gaps):
    if not path.exists():
        if live:
            gaps.append('T3 process observed but metadata database missing; task activity unknown.')
        return []
    rows = []
    try:
        with read_db(path) as db:
            query = '''SELECT t.thread_id, p.workspace_root, t.payload_json,
                r.status, r.requested_at, r.completed_at
                FROM orchestration_v2_projection_threads t
                JOIN projection_projects p ON p.project_id=t.project_id
                LEFT JOIN orchestration_v2_projection_runs r ON r.thread_id=t.thread_id
                AND r.ordinal=(SELECT MAX(r2.ordinal) FROM orchestration_v2_projection_runs r2
                               WHERE r2.thread_id=t.thread_id)
                WHERE t.deleted_at IS NULL AND t.archived_at IS NULL'''
            for row in db.execute(query):
                try:
                    payload = json.loads(row['payload_json'])
                    if not isinstance(payload, dict):
                        raise ValueError('Unexpected metadata type')
                    selection = payload.get('modelSelection') or {}
                    options = selection.get('options', []) if isinstance(selection, dict) else None
                    if not isinstance(selection, dict) or not isinstance(options, list):
                        raise ValueError('Unexpected selection type')
                except (ValueError, TypeError):
                    gaps.append('T3 row contains unsupported metadata; that task activity is unknown.')
                    continue
                root = payload.get('worktreePath') or row['workspace_root']
                if not related(root, workspace):
                    continue
                effort = next((x.get('value') for x in options
                               if isinstance(x, dict) and x.get('id') == 'reasoningEffort'), None)
                status = row['status'] or 'unknown'
                # A DB left behind by a closed/crashed harness is not liveness proof.
                observed = status if live else 'unknown-harness-not-observed'
                rows.append(dict(harness='t3', id=row['thread_id'], workspace=root,
                                 model=model_name(selection.get('model')),
                                 reasoning=effort if effort in ('none','minimal','low','medium','high','xhigh','max','ultra') else 'unknown',
                                 state=observed, recorded_state=status, source='t3-readonly-sqlite',
                                 requested_at=row['requested_at'], completed_at=row['completed_at']))
    except (sqlite3.Error, ValueError, OSError, TypeError):
        gaps.append('T3 metadata unavailable or schema unsupported; activity unknown.')
    return rows


def last_task_state(path, limit=262144):
    """Parse only task lifecycle events from a bounded tail; never emit messages."""
    try:
        with Path(path).open('rb') as stream:
            stream.seek(0, 2)
            start = max(0, stream.tell() - limit)
            stream.seek(start)
            if start:
                stream.readline()
            lines = stream.read(limit).splitlines()
        state = 'unknown'
        for line in lines:
            if b'"event_msg"' not in line:
                continue
            try:
                data = json.loads(line)
                event = data.get('payload', {}).get('type')
                if data.get('type') == 'event_msg':
                    if event == 'task_started':
                        state = 'running-recorded'
                    elif event in ('task_complete', 'task_completed', 'turn_aborted'):
                        state = 'idle-recorded'
            except (ValueError, TypeError, AttributeError):
                continue
        return state
    except (OSError, TypeError, ValueError):
        return 'unknown'


def codex_threads(path, workspace, exclude_id, live, gaps):
    if not path.exists():
        if live:
            gaps.append('Codex process observed but metadata database missing; task activity unknown.')
        return []
    rows = []
    try:
        with read_db(path) as db:
            for row in db.execute('''SELECT id,cwd,rollout_path,model,reasoning_effort,originator
                    FROM threads WHERE archived=0 AND updated_at>=? ORDER BY updated_at DESC LIMIT 80''',
                                  (int(time.time()) - 21600,)):
                if row['id'] == exclude_id or not related(row['cwd'], workspace):
                    continue
                # T3 is represented by its live orchestration projection, without double-counting.
                if row['originator'] == 'T3 Code':
                    continue
                state = last_task_state(row['rollout_path']) if live else 'unknown-harness-not-observed'
                rows.append(dict(harness='codex', id=row['id'], workspace=row['cwd'],
                                 model=model_name(row['model']), reasoning=model_name(row['reasoning_effort']), state=state,
                                 source='codex-metadata-and-bounded-lifecycle-tail'))
    except (sqlite3.Error, ValueError, OSError):
        gaps.append('Codex metadata unavailable or schema unsupported; activity unknown.')
    return rows


def snapshot(workspace, exclude_id=None, home=HOME):
    gaps = []
    try:
        processes = process_snapshot()
    except (OSError, ValueError, subprocess.SubprocessError):
        processes = []
        gaps.append('Windows process query failed; harness liveness unknown.')
    kinds = {x['kind'] for x in processes}
    threads = t3_threads(home / '.t3/userdata/statev2.sqlite', workspace, 't3-app' in kinds, gaps)
    threads += codex_threads(home / '.codex/state_5.sqlite', workspace, exclude_id,
                             'codex-server' in kinds, gaps)
    return dict(schema_version=1, observed_at=dt.datetime.now(dt.timezone.utc).isoformat(),
                host=os.environ.get('COMPUTERNAME', 'unknown'), workspace=workspace,
                processes=processes, relevant_threads=threads, gaps=gaps,
                limits=['Snapshot only; no filesystem lock or complete agent census.',
                        'Recorded run state can survive a crashed worker; confirm scope before edits.',
                        'Claude/AGY/OpenCode are process-only; unknown activity.',
                        'Codex: last 6 hours, at most 80 records, 256 KiB lifecycle tail per thread.'])


def compact(data):
    lines = ['AGENT AWARENESS | ' + safe(data['host']) + ' | ' + safe(data['workspace'])]
    processes = data['processes']
    lines.append('Harness processes: ' + (', '.join(x['kind'] + ':' + str(x['pid']) for x in processes) or 'none observed'))
    for row in data['relevant_threads'][:8]:
        lines.append('{harness} {id} | {state} | {model}/{reasoning} | {workspace}'.format(**{k:safe(v) for k,v in row.items()}))
    if len(data['relevant_threads']) > 8:
        lines.append('More related sessions omitted; run with --json for complete bounded snapshot.')
    if data['gaps']:
        lines.extend(data['gaps'])
    lines.append('App open != agent busy. Activity may be unknown. Check scope before edits; use separate worktrees for concurrent product changes.')
    return '\n'.join(lines)


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(errors='backslashreplace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace')
    parser.add_argument('--exclude-session')
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--hook', action='store_true', help='Read SessionStart payload on stdin; errors remain visible and nonblocking.')
    args = parser.parse_args()
    payload = {}
    if args.hook and not sys.stdin.isatty():
        try:
            payload = json.loads(sys.stdin.read(65536) or '{}')
            if not isinstance(payload, dict):
                payload = {}
        except ValueError:
            payload = {}
    workspace = args.workspace or payload.get('cwd') or os.getcwd()
    exclude_id = args.exclude_session or payload.get('session_id') or os.environ.get('CODEX_THREAD_ID')
    data = snapshot(workspace, exclude_id)
    print(json.dumps(data, ensure_ascii=True) if args.json else compact(data))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
