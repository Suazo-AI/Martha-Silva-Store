# E2: seeded bug drill (preparation only)

No agent has run this drill and no product bug is seeded in this delivery.
The primary later assigns a fresh agent only `docs/AGENT-START.md` and `docs/MAINTENANCE.md` as entry documents.
The agent must follow their links and inspect the source without the original author.

Use a separate disposable checkout with an explicitly assigned branch and scope.
The coordinator records its SHA and seeds this one-line bug in `tools/doctor.py` before the agent starts.
Change `code = int(counts['FAIL'] > 0)` to `code = 0`.
The symptom is that doctor reports FAIL but returns success to its caller.
Do not seed or commit the bug in Tony.

The expected red test is `DoctorTests.test_failure_read_next_and_exit_one` in `tests/test_doctor.py`.
Run `python tests/test_doctor.py` and expect that assertion to fail because exit 0 differs from 1.
The JSON exit-code test also detects this seed.
The expected fix restores failure-sensitive exit status without changing PASS or SKIPPED behavior.
Require the agent to add a mixed PASS/FAIL/SKIPPED regression and demonstrate exit 1.
Require an all-SKIPPED control to remain exit 0 and preserve its explicit omissions.
An import error, missing tool or empty test suite does not satisfy the red criterion.

After the fix, run `python tests/test_doctor.py` and both doctor modes.
Existing unrelated environment failures must be reported separately from the repaired drill.
With separate commit authority, preserve seeded-base and fixed-head SHAs and run `python tools/bugproof/prove.py --base <seed-sha> --head <fix-sha>`.
The changed mixed-result regression must fail on the seeded base and pass on the fixed head.
Without commit authority, keep changes staged and report bug-proof NOT RUN.
No SQL, network, Docker, secrets, deploy, merge or agent invocation is needed to prepare this drill.

Acceptance requires the fresh agent's actual red/green outputs, exact SHAs, diff, doctor results and primary review.
The primary owns scheduling, isolated seeding, review and cleanup of the future drill.
E2 remains NOT RUN until that evidence exists.
