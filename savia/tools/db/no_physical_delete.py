#!/usr/bin/env python3
"""Static check (ADR-001 D5, critique F10): no DELETE or TRUNCATE on synced tables.

A synced table is one with Change Tracking enabled in a migration
(ALTER TABLE [s].[t] ENABLE CHANGE_TRACKING). Change Tracking reports a physical delete
only as a key, and TRUNCATE is not tracked at all, so both break the replicas.
Corrections must be new rows (reversal, transition, status change).

Scans db/migrations/*.sql after comments are removed. Exit 0 = no violation.
Usage: python savia/tools/db/no_physical_delete.py
"""
import re
import sys
from pathlib import Path

MIGRATIONS = Path(__file__).resolve().parents[2] / "db" / "migrations"
NAME = r"\[?(\w+)\]?\.\[?(\w+)\]?"
TRACKED = re.compile(rf"ALTER\s+TABLE\s+{NAME}\s+ENABLE\s+CHANGE_TRACKING", re.I)
WRITE = re.compile(rf"\b(DELETE\s+(?:TOP\s*\(\s*\d+\s*\)\s+)?(?:FROM\s+)?|TRUNCATE\s+TABLE\s+){NAME}", re.I)


def strip_comments(sql):
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    return re.sub(r"--[^\n]*", " ", sql)


def scan(files):
    texts = {p.name: strip_comments(p.read_text(encoding="utf-8")) for p in files}
    tracked = {(s.lower(), t.lower()) for text in texts.values() for s, t in TRACKED.findall(text)}
    hits = []
    for name, text in texts.items():
        for m in WRITE.finditer(text):
            key = (m.group(2).lower(), m.group(3).lower())
            if key in tracked:
                line = text.count("\n", 0, m.start()) + 1
                hits.append(f"{name}:{line}: {m.group(1).split()[0].upper()} on synced table {key[0]}.{key[1]}")
    return tracked, hits


def main():
    tracked, hits = scan(sorted(MIGRATIONS.glob("V*.sql")))
    for h in hits:
        print(h)
    print(f"{len(tracked)} synced tables, {len(hits)} physical deletes")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
