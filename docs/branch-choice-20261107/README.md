# API-BRANCH: decision aid

Status: local explanation for Jason. No choice received. No implementation authorization is inferred from a draft.

- [Open the interactive comparison](decision.html).
- [Five exact options and scopes](choice.json).
- [Verification and limits](preview-check.json).

Jason requested one question, a recommendation, hypothetical examples and five choices labeled A–E. A preserves D-014 (one business, one operational branch). B adds an Owner-facing setup screen for that single branch. C/D propose several branches and require further rules before implementation. E defers the decision for a demonstration.

Direct sources: `docs/DECISIONS.md` D-014, `docs/pipeline/ledger.json` API-BRANCH, and `dev/savia-staff-ui/styles.css`, read 2026-11-07. All store names, actors and quantities in examples are fictitious.

`python docs/branch-choice-20261107/build.py` exited 0. It uses a private copy of the installed DECISIONS renderer, adapting its four-option limit to Jason's explicit five-option request. The global skill is unchanged. `decision.html` is self-contained. Rebuilding requires that installed skill at its recorded path.

Visual previews: 728px and 390px; zero console messages. An initial theme mapping made secondary text unreadable; `--muted-foreground` corrected it and both fresh previews were inspected. The standalone file uses SAVIA's existing colors. The inline T3 version uses T3 theme colors.

The disposable DOM probe passed five option changes, three scenario controls, initially unanswered state, review/edit, draft restoration and disabled standalone sending. Two earlier incomplete probe attempts and the `scrollTo` stub are disclosed in `preview-check.json`. This is not a real browser click sequence. No live bridge submission, user receipt or production claim was fabricated. The existing DECISIONS transport code was reused.

Lavish accepted the handback reply with exit 0. No active feedback listener is claimed. Jason can answer through T3's question or explicitly send from Lavish.

Next owner: Jason chooses A–E. Primary records the received choice before implementing its permitted scope. Independent session-CSRF and runner reviews do not depend on this choice.
