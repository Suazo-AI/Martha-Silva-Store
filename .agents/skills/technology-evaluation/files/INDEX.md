# Technology evaluation skill — reusable files

| File | Purpose | Use |
|---|---|---|
| `../SKILL.md` | Canonical end-to-end policy | Read first; defines triggers, roles, sequence, gates, scoring, and completion checks |
| `RUN-PACKET.md` | Reusable per-run record | Copy to `evidence/technology-evaluations/<slug>/<run-id>/RUN-PACKET.md` and complete as the run progresses |

## Evidence separation

- The skill is policy. Do not append run-specific results to it.
- Every technology evaluation gets its own evidence folder.
- Keep actual command output, CI links, test artifacts, and reviewer reports in that run folder.
- Do not create `examples/` entries until a user approves the run as a reusable example.
- Record reusable process corrections in `../notes.md`, with date and the failing evidence that justified the correction.
