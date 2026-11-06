# Jason frontend with Denis images

2026-11-05. Primary: SUAZO-PC / T3 Code / Codex / gpt-6.1-sol, xhigh.
Base: `6d8d53c964ca07cf173e3683a7660624d955aa4c`, Tony.

Jason explicitly selected his published style, layout and frontend.
Denis supplies only the images. The primary's earlier recommendation of Denis's composition was wrong.
This correction is the selected reference, not a new design proposal (D-030).

## Sources

- Frontend: https://martha-silva-demo.jason-suazof.workers.dev/.
- Images: https://martha-silva-preview.martha-silva-denis.workers.dev/.
- Current behavior and assets: `src/`, `build-inputs/static/`, `prepare.py`.
- Prior direct findings: `PREVIEW-COMPARISON.md`; screenshots outside the build.

## Frozen acceptance checks

1. Bind the Jason frontend reference to exact retrieved files/hashes or a verified Git source. Do not guess its source SHA.
2. Use Jason's page structure, styling and navigation across home, catalog, product and purchase pages. Preserve the current working demo behavior.
3. Preserve all existing authorized Denis image originals and responsive derivatives. Map any missing or different live image explicitly before substitution.
4. Remove reliance on Denis's editorial composition. Do not invent a third visual direction.
5. Preserve accessibility, required legal/demo/IA labels, preview noindex, product identities, existing routes and current safe purchase semantics.
6. Build from source; test focused frontend, localization, catalog, imagery and fonts. Do not replace current behavior wholesale with older scripts.
7. Record matched desktop/mobile reference and candidate views and critical-path behavior. Keep actual browser evidence separate from DOM tests.
8. Return changed paths, hashes, commands/exits, evidence and gaps. No deployment or automatic acceptance.

## Coordination and integration

Hardening worker returned its separate candidate at `C:/Users/Jason/.t3/worktrees/github/t3-d220fd88`.
Its checks do not certify the combined frontend. Review and integration are pending.
Frontend work uses a separate managed worktree and excludes hardening-owned files.
The primary imports source serially, regenerates dist and the current manifest, then verifies the combined candidate.
Independent critic/judge, exact-SHA CI and live verification remain required before release acceptance.
Old public sites stay intact; no production payment, staff runtime or operational gate is closed by this work.

## Blocker ownership

| Item | Cause / evidence | Correction and result | Owner / next action / completion check |
| --- | --- | --- | --- |
| Wrong visual selection | Primary conflated selecting Denis images with selecting Denis layout. Jason corrected this explicitly. | D-030, comparison and current plan corrected. Hardening worker received the correction before return. | Primary; verify candidate matches Jason frontend with Denis images before acceptance. |
| Jason source SHA unknown | Prior live files differ from canonical HEAD and have no public deployment marker. | Preserve recorded source hashes; no guessed SHA. | Frontend worker; retrieve public source or locate matching Git bytes and record provenance. |
| Integrated verification pending | Hardening returned against the current frontend; requested composition changes are not integrated. | No deployment attempted. | Primary; combined browser proof, independent review and exact-SHA Linux CI. |
| Windows symlinks | Known WinError 1314 in aggregate audit fixtures. | Keep host controls; do not repeat the known failure as a repair strategy. | Primary; exact integrated SHA on Linux CI. |

Lesson: treat frontend, imagery and hosting as three distinct selections. A shared account does not imply a shared design.
