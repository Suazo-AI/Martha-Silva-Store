# Owner decisions: local verification, 2026-11-12

Candidate: uncommitted working tree in the canonical checkout. Work stayed on branch Tony.
No commit, push, deployment, new dependency, container or paid/external service was used.
The previous worker's catalog grid, Ajustes, parked tickets, discounts and seed labels were retained.
Product photos were removed as requested. V001 was not edited.

## Red checks

Before the SQL changes, the focused .NET command selected
`Opening_amount_must_equal_denominations`, `Cashier_discount_requires_live_local_supervisor`
and `Zero_stock_sale_records_exception_and_keeps_conservation`.
It exited **1** with **3 failed, 0 passed**. These covered the mismatched opening,
the former cashier allowance, and the rejected physical-stock sale.

An intermediate counted-opening/closing test exited **1**. SQL reported error 2601 on
`UX_CashCounts_TillSubmitted`: the opening count prevented a closing count. V015 changes that
index to `(TillId, CountKind)` and retains a separate single-opening index. It also prevents
using the opening count to close a till. The close procedure retains V007's branch access check.

The prior accounting fixture also failed under the new discount rule. Its sale now supplies
the fixture manager and a reason. The corrected focused command
`python savia/tools/db/saviadb.py test cash/123 --jobs 1` exited **0**.

The full-discount web regression initially failed because a positive tender was required for
a zero-total ticket. The corrected web suite has 42 passing tests. The API now permits an empty
tender list; SQL still checks that the tender sum equals the authorized sale total.

## SQL accounting

A physical-stock sale creates a `sales.StockExceptions` record per short sale line.
SQL posts an adjustment of **+quantity short**, sourced to that exception, followed by the
normal sale movement of **−quantity sold**, sourced to the sale. Both commit in one transaction.
The sale still has exactly its normal stock movement. Reserved quantities stay reserved.
Retries create neither another exception nor another movement. Manager review is audited in
`sales.StockExceptionReviews` and retains the first review on retry.

`python savia/tools/db/saviadb.py test 150_owner --jobs 1` exited **0**. It verifies opening
validation/persistence/retry, a 90% manager discount, rejected cashier discount, sequential receipt,
zero-stock adjustment and sale, one exception, manager review/retry, and zero conservation violations.

## Acceptance

All final checks passed. The API is stopped. No required owner decision remains unfinished.

| Command | Exit | Result |
| --- | --- | --- |
| `python savia/tools/pilot.py down` then `python savia/tools/check.py` | 0 / 0 | RESULT PASS; 129 SQL tests; 43 .NET tests; no skips. The final source includes the full-discount API case. |
| `node --test "savia/web/tests/*.test.mjs"` | 0 | 42 passed |
| `python savia/tests/test_pilot_browser_cleanup.py` | 0 | 3 passed; a live session still fails cleanup |
| `python savia/tools/pilot.py reset` then `python savia/tools/pilot.py up` | 0 / 0 | V001–V016; local sample seed; three separate random passwords |
| `python -u savia/tools/pilot_smoke.py` | 0 | Receiving, opening breakdown, sales/returns, cashier rejection, manager approval/reason, receipt, zero-stock exception/review, four report periods, balanced close and conservation |
| `python -u savia/web/tests/e2e_pilot.py` — pass 1 | 0 | All flows; console 0; page errors 0 |
| Same browser command — pass 2, without reset | 0 | All flows again; console 0; page errors 0 |
| `EXEC audit.usp_CheckConservation @Throw=1` after both browser passes | 0 | Zero violations |
| `python savia/tools/pilot.py down` | 0 | Pilot PID stopped; loopback health refused |
| `python savia/.out/owner_receipt_probe.py` | 0 | Final receipt encoding, human number, no tax/images, both viewports, console/page errors 0 |
| Product image/source audit | 0 | No image folder, helper, markup, URLs or placeholders in production web files |
| `git diff --cached --check` | 0 | Staged diff passes whitespace checks |

The browser runner checks page and ticket scrollWidth <= clientWidth and ticket control bounds
at 1024x768 and 1440x900 for captured states. Screenshots are 1024x768. Venta, opening, Cierre,
Reportes and Excepciones were visually inspected. [WEB-VERIFICATION](screens/WEB-VERIFICATION.json)
records screenshot hashes and run results. Obsolete captures were removed.

An earlier browser run passed every flow with zero console/page errors but failed while closing
the CLI. A diagnostic query also overlapped one shutdown attempt. Final runs leave browser control
entirely to the suite. Cleanup waits at most five seconds for its session entry to disappear and
fails if it stays active. A lost acknowledgement alone does not hide a live session.

A final receipt-only UTF-8 correction followed the two complete browser passes. The 42 web units
were rerun after it, and a separate real-API receipt check verified its text, number, image absence,
print content and both viewport widths. The receipt screenshot was refreshed.

The smoke assertion now compares UUID values rather than letter case in their JSON strings.
Local raw logs are ignored under `savia/.out/owner-*.log`.
Passwords are random per account in the process environment. They are not saved in this report.
Browser credentials use the agent-browser encrypted vault, with each temporary profile removed.

## Limits

Reports cover the local branch and NIO. Weeks start Monday. Customers served count identified
buyers. New customers have no earlier sale at this branch. Sales-by-day rows omit inactive days.
CSV uses the same SQL response and minor-unit amounts. No CRM integration is deployed.

The receipt is a simple store receipt. No fiscal invoice or tax breakdown is presented.
Returns remain store-credit returns. Card/transfer references are externally completed payments.

Not verified: deployment, production, payment gateway, physical scanner, paper printing,
mobile, full accessibility/performance, or multi-node synchronization. Browser screenshots
and overflow checks do not establish these properties.

## Staging

Explicit reviewed paths: [FILES-STAGED](FILES-STAGED.txt). Unrelated root changes and the prior
`cp4-sim` evidence remain unstaged. No secrets or raw logs are staged. No commit or push was made.
