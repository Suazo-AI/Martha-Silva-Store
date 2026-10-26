# Publication candidate: Back, approved support illustrations and footer link removal

User explicitly requested publication here on 2026-10-26, referring to instructions in Cutufay. Slack thread PHOTO-QUALITY-AUDIT-20261025 supplied the final v4 package and the additional request to remove the public demo-admin footer link. The current authorized preview Worker was freshly confirmed at A version a8668b7b-9fe0-4635-ac5a-01033ae96e2b, 100% traffic, before integration.

The sealed v4 ZIP SHA256 is 0bfabaf6cd0266f1b672ae2ec17dc9689198db63f544115a1d49a6b6bfe544e1. Its app, CSS and two approved PNGs are unchanged. Its two product HTML inserts are unchanged except for the same footer removal applied across all 47 pages. Each footer change removes exactly one literal anchor and preserves every other byte. The admin route and authentication are unchanged.

Final runtime: 904 routes, 853 unchanged from A, 49 modified text files (app, CSS and 47 HTML), two added support PNGs. All original photographs, the 40 products, 120 variants and 170 gallery positions remain. Green B, broad exclusions and other image-generation proposals are not integrated.

Evidence under `evidence/` and `manifests/` in this directory is the immutable cloud v4 delivery, not the identity of this additional footer derivative. `footer-delta.json`, `final-integration-check.json` and `final-runtime-hashes.json` identify the final local integration. The publisher generates a separate marker with the actual integrated source commit.

Cloud v4 suite status is pass_with_documented_fixture_adaptation. Preserve the original Green 5/6 failure and approved evidence-only 6/6 adaptation; do not count them as eleven cases or imply an unqualified original pass. The footer received bounded exact-byte, source/dist and HTML-parser checks locally; no build, browser QA or heavy suite was run on Tony. The tested cloud build maps these inputs to runtime without transformation.

Independent lightweight reviewers assessed source, payload integrity and presentation contracts. Browser rendering, native Safari/iPhone back navigation, BFCache and VoiceOver are not established by JSDOM tests. Postpublication coverage must be recorded separately. A possible sticky-header overlap when the new link returns to original photographs is an observation target, not a confirmed source blocker.

Rollback restores the entire A version, not app.js alone. Fresh destination guards must still hold immediately before publication.
