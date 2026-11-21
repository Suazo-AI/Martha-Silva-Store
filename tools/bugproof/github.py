"""Trusted GitHub control plane; GITHUB_TOKEN only; no PR code execution."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.request


def api(method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(os.environ.get('GITHUB_API_URL', 'https://api.github.com') + path,
        data=data, method=method, headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
        'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def pages(path):
    result = []
    for page in range(1, 101):
        batch = api('GET', path + ('&' if '?' in path else '?') + f'per_page=100&page={page}')
        result.extend(batch)
        if len(batch) < 100:
            return result
    raise RuntimeError('Pagination limit reached; refusing incomplete dedupe.')


def intake(event, repo):
    run = event['workflow_run']
    if run['conclusion'] != 'failure' or run['head_branch'] != 'Tony' or run['head_repository']['full_name'] != os.environ['GITHUB_REPOSITORY']:
        return
    # Jobs API wraps the paginated array.
    jobs = []
    page = 1
    while True:
        batch = api('GET', repo + f"/actions/runs/{run['id']}/jobs?filter=latest&per_page=100&page={page}")['jobs']
        jobs.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    issues = pages(repo + '/issues?state=all&labels=bug')
    for job in jobs:
        if job['conclusion'] != 'failure':
            continue
        key = hashlib.sha256(f"{run['workflow_id']}:{job['name']}".encode()).hexdigest()
        marker = '<!-- bugproof:intake:' + key + ' -->'
        body = f"{marker}\nCI failed on Tony.\nWorkflow: {run['name']}\nJob: {job['name']}\nSHA: `{run['head_sha']}`\nJob URL: {job['html_url']}\n\nReproduce with a failing test before fixing."
        existing = next((i for i in issues if marker in (i.get('body') or '') and 'pull_request' not in i), None)
        payload = {'title': ('CI bug: ' + run['name'] + ' / ' + job['name'])[:240], 'body': body, 'labels': ['bug']}
        if existing:
            payload['state'] = 'open'
            api('PATCH', repo + '/issues/' + str(existing['number']), payload)
        else:
            issues.append(api('POST', repo + '/issues', payload))


def gate(event, repo):
    pr = event['pull_request']
    required = any(l['name'] == 'bug' for l in pr['labels'])
    # References are deliberately conservative: all local Fixes/Closes references require proof.
    required |= bool(re.search(r'\b(?:fixes|closes)\s+#\d+', pr.get('body') or '', re.I))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('required=' + str(required).lower() + '\n')


def comment(event, repo):
    number = event['pull_request']['number']
    body = Path('bugproof-report/report.md').read_text(encoding='utf-8')
    if len(body) > 60000:
        raise ValueError('Report too large for comment; see artifact.')
    path = repo + f'/issues/{number}/comments'
    existing = next((c for c in pages(path) if '<!-- bugproof:report -->' in c.get('body', '') and c['user']['login'] == 'github-actions[bot]'), None)
    if existing:
        api('PATCH', repo + '/issues/comments/' + str(existing['id']), {'body': body})
    else:
        api('POST', path, {'body': body})


if __name__ == '__main__':
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    {'intake': intake, 'gate': gate, 'comment': comment}[sys.argv[1]](event, '/repos/' + os.environ['GITHUB_REPOSITORY'])
