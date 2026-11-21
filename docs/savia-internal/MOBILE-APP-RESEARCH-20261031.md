# SAVIA on iPhone and Android — research and proposed acceptance

31 October 2026, Nicaragua. Mode: DISCOVER. Host: SUAZO-PC. Agent: Codex, GPT-6 family; exact model variant is not exposed.

**Recommendation:** adapt the existing staff interface into an installable web app (PWA), backed by the existing .NET API. Prove the sale and stock workflow first. Consider native packaging only when a demonstrated requirement needs it.

Jason confirmed **iPhone and Android** in this chat. The platform choice is confirmed; this architecture and implementation scope are proposals awaiting approval. This document is research, not a working mobile application or a production-readiness claim.

## Outcome and smallest useful experiment

The owner should check stock and record a sale from a phone, then see the same receipt and stock after reopening SAVIA. Staff must only access their authorized operations and location.

The bottleneck is a verified operational workflow and reachable private backend. An install icon alone does not solve either problem. The smallest experiment is one synthetic sale, one location, one authorized user, and persistence after reload. Measure task completion and errors with the owner before adding more modules.

Research used local reads and public sources. No paid generation, account registration, skill installation, runtime launch, SQL execution, certificate change, or deployment was performed. Implementation effort and hosting cost have not been estimated. Stop before implementation until the proposed acceptance is approved; stop expansion if the first workflow cannot pass.

## What the supplied reference establishes

Supplied source: [Paul Solt, 10 April 2026](https://x.com/PaulSolt/status/2042716870512353294).
Direct X status and article retrieval returned **403 Forbidden**. Full thread coverage is unavailable. The accessible [companion newsletter by Solt](https://super-easy-apps.kit.com/posts/install-these-skills-before-codex-touches-your-xcode-project) links to the article and describes guidance for Swift, SwiftUI, concurrency, Liquid Glass, and Apple-platform development.

This supports investigating Apple development guidance. It does not establish a business-management app specification, Android support, or a guarantee of correct generated code. No video was watched or transcribed.

### Curated coding references

| Source | What was inspected | Use for SAVIA |
| --- | --- | --- |
| [Paul Hudson: SwiftUI Pro](https://github.com/twostraws/SwiftUI-Agent-Skill) | README and `swiftui-pro/SKILL.md`, metadata version 2.0.0 | Conditional: native SwiftUI review, accessibility, state and navigation. Check target and SDK assumptions before use. |
| [Paul Hudson: Swift Concurrency Pro](https://github.com/twostraws/Swift-Concurrency-Agent-Skill) | `swift-concurrency-pro/SKILL.md`, metadata version 1.0 | Conditional: native actor isolation, cancellation and async correctness. |
| [Paul Hudson: Swift Testing Pro](https://github.com/twostraws/Swift-Testing-Agent-Skill) | `swift-testing-pro/SKILL.md`, metadata version 1.0 | Conditional: native unit/integration testing. UI automation needs its own tooling. |
| [Antoine van der Lee: SwiftUI Expert](https://github.com/AvdLee/SwiftUI-Agent-Skill) | Repository README and current source tree | Alternative SwiftUI guidance. The guessed raw path failed; source tree identifies `skills/swiftui-expert-skill/SKILL.md`. Payload not vetted for installation. |
| [Thomas Ricouard: Skills](https://github.com/Dimillian/Skills) | Repository descriptions of focused skills | Conditional: SwiftUI patterns and performance review. Individual payloads not vetted. Community authorship; no claim of official OpenAI endorsement. |
| [Paul Solt: AppCreator](https://super-easy-apps.kit.com/app-creator) | Author's distribution page | Conditional: repeatable Xcode CLI build/test loop. Download requires a signup form; no signup or payload acquisition performed. |

The installed-skills query `npx -y skills@latest ls -g --json` returned no matching Swift/iOS/Android/Capacitor/Expo/mobile entries. This query concerns CLI-managed skills, not every plugin or file on the PC. No install is recommended for the first PWA slice. Three Hudson entry files were read; their referenced subfiles and executable payloads were not audited. No package is certified safe by this research.

For the proposed PWA, prioritize the existing web implementation, current browser documentation, focused .NET checks, and real iPhone/Android tests. Expert instructions supplement those checks. They do not replace them.

## Direct SAVIA source findings

Checkout HEAD at inspection: `aca910acd05b4766e9979a6a37f555cb9716e149`, branch `Tony`.
The working tree contains concurrent, uncommitted SQL/security/staff-interface work. This research preserves it. [Inspection manifest](mobile-app-20261031/source-observations.json) records selected file hashes; it does not export that work or its private artifacts.

| Finding | Direct source and limit |
| --- | --- |
| The staff frontend is HTML/CSS/JavaScript, separate from the public store. | [Staff README](../../dev/savia-staff-ui/README.md), [UI hosting](../../backend/src/Martha.Store.Api/Internal/InternalUiHosting.cs). Staff documents/scripts require authorization. |
| The API uses ASP.NET Core, EF Core and SQL Server. | [Backend project](../../backend/src/Martha.Store.Api/Martha.Store.Api.csproj). A native app need not replace this backend. |
| Browser authentication assumes one origin. | [Security](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs) uses `__Host-Savia.Session`, HttpOnly, Secure, SameSite=Strict; [login client](../../dev/savia-staff-ui/login.mjs) uses `credentials: 'same-origin'`, CSRF and `cache: 'no-store'`. |
| Local client work includes stock and a constrained sale path. | [Client](../../dev/savia-staff-ui/client.mjs): inventory, sale submission, sale retrieval and operation recovery. Current sale validation requires exactly one line and `customerId: null`. This is code inspection, not successful phone operation. |
| Sales are records, not bank payments. | Client receipt validation requires `paymentStatus: 'not_processed'`. Money uses integer minor units, server-returned prices and currency. |
| API modules include sales, adjustments, reversals, directory, purchase orders and receipts. | [Commerce routes](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceEndpoints.cs), [supply routes](../../backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs), [directory routes](../../backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs). Route existence alone does not prove operational readiness. |
| An installable staff app is not present in the inspected sources. | No manifest/service-worker/icon files found under `dev/savia-staff-ui`. The backend embeds six explicit staff resources. New assets need explicit hosting/resource changes. |

The local SQL area contains newer evidence than `SAVIA-LATEST.md` and older staff READMEs. At inspection, its test matrix states **8/22 operational criteria PASS**, **14 NOT RUN**, and **1/5 critical UI criteria PASS**. The local record reports **512 unique internal tests PASS, including 46 SQL tests**; these were not rerun here. The UI sale, stock readback after that sale, and application-restart persistence remain NOT RUN in that matrix.

Those records are concurrent local work, not part of this research publication. Their counts are an observation at inspection time. Do not combine historical 581, 512 and focused-test counts, or treat them as completed business workflows. No claim about the current running service state is made here.

## Architecture decision

| Route | Benefit | Cost and constraint | Recommendation |
| --- | --- | --- | --- |
| Responsive, installable PWA | Reuses staff UI and browser auth; one interface for iPhone, Android and desktop. | Requires approved reachable HTTPS backend, responsive flow and actual install/reopen checks. OS/browser capabilities vary. | First experiment. |
| Capacitor packaging | Reuses web UI with access to native integrations and distribution. | Separate native builds, signing and device QA. App origin/cookies/CSRF require a proven authentication design. iOS builds need macOS/Xcode. | Reconsider when a measured native need appears. |
| Separate native clients | Platform-specific experience and integrations. | New frontend implementations, API transport/auth work, separate release and test paths. SwiftUI covers Apple platforms, not Android. | Defer for this existing web product. |

These are engineering judgments, not benchmark results. Relevant primary documentation: [PWA installation](https://web.dev/learn/pwa/installation), [Capacitor overview](https://capacitorjs.com/docs), [environment requirements](https://capacitorjs.com/docs/getting-started/environment-setup), [iOS cookie constraints](https://capacitorjs.com/docs/apis/cookies), and [Apple Xcode requirements](https://developer.apple.com/xcode/system-requirements).

### Proposed technical boundary

- Serve the staff app and its API from the same approved private application origin. Keep it separate from the public store.
- Preserve server authorization, branch scope, HttpOnly/Secure cookies, CSRF and response validation. Do not weaken them to make packaging work.
- Add a manifest, approved icons, start URL and explicit staff-resource routes. Determine installation behavior on each target device.
- If adding a service worker, initially cache only explicitly public presentation resources and a generic offline page. Never cache authenticated HTML, API responses, credentials or customer records in the first slice.
- Require connectivity for business writes. Do not queue or automatically replay sales, returns or stock adjustments offline.
- Preserve the original operation key and payload for an unknown result. Recovery must survive a reload without persisting credentials or customer data. The safe minimal recovery record and expiry rules require design and tests before implementation.
- Use the actual price, currency and receipt from the server. Distinguish a recorded sale from a processed payment.
- Keep new code in existing staff modules unless a demonstrated need justifies a new dependency. No frontend-framework rewrite is proposed.

Supporting guidance: [offline storage](https://web.dev/learn/pwa/offline-data) describes storage choices; its availability is not permission to store business data. [OWASP MASVS](https://mas.owasp.org/MASVS/) is relevant to later native packaging. It is not a compliance certification for SAVIA.

## Business coverage: target versus present evidence

| Area | Phone outcome to pursue | Current evidence and boundary |
| --- | --- | --- |
| Sales and inventory | Search stock, record a sale, retrieve receipt and durable stock movement. | Existing API and local client work; first end-to-end phone proof pending. |
| Customers and suppliers | Find an authorized contact and review confirmed transactions. | Directory routes exist; mobile editing/history acceptance is not established. |
| Purchasing | Issue purchase order, receive partially, inspect remaining quantities. | Routes and local operational evidence exist; phone UI acceptance is pending. |
| Owner and staff | Apply server roles, revoke access, inspect authorized actions. | Server policies and staff routes exist; mobile lifecycle and revocation proof pending. |
| Owner overview | Show confirmed activity and actionable stock/purchase exceptions. | Proposed; aggregate/report contracts and definitions must be agreed. No invented totals. |
| Finance and the rest of the business | Cash closing, expenses, debts, accounting, payroll, tax documents, banks and external integrations. | No complete implementation established by this inspection. Each needs workflow discovery and separate scope. |

“Control the whole business” is the long-term outcome. It does not mean all these modules are already delivered. Preserve the current approved pilot boundary of one business and one branch until a new scope is approved.

## Proposed first-slice acceptance — approval pending

| ID | Acceptance check | Evidence required |
| --- | --- | --- |
| M01 | Authorized login and logout on iPhone and Android; anonymous API denied. | Real device/browser network results; protected data removed after logout, expiry and 401. |
| M02 | Stock search identifies item, variant and location; no stale data represented as live. | Compare authorized API response with the visible result. Narrow viewport and keyboard checks. |
| M03 | Submit one synthetic sale and show its real receipt. | Receipt ID, server amount/currency, SQL ledger effect, reload readback. No payment claim. |
| M04 | Double tap/retry cannot create a second sale; changed payload with the same key conflicts. | One durable sale and one stock debit; exact replay identity and conflict evidence. |
| M05 | Lost response after commit can be recovered after reload using the original operation identity. | Controlled response-loss test; resolve original receipt without a new key or duplicate debit. |
| M06 | Losing connectivity blocks new business writes and never reports success. | Real offline/reconnect sequence; no queued business mutation or protected cache entry. |
| M07 | Staff cannot cross permissions or branch scope through direct API requests. | Forbidden requests and revocation/session tests, not button visibility alone. |
| M08 | App installs, launches, resumes and reopens correctly on one actual iPhone and one actual Android. | Device/OS/browser versions, install/start URL, login lifecycle and safe-area behavior. Emulation is supplementary. |
| M09 | Flow works with touch, keyboard, screen reader labels and enlarged text. | 320/390/430 CSS-pixel layouts, desktop regression, focus order and labeled controls; no clipped primary action. |
| M10 | Existing staff and public-store behavior remains intact. | Focused existing checks and critical-path regression. Original before/after browser recordings of the changed staff flow, followed by Jason's visual review. |

No mobile acceptance check was executed in this research. Product tests were not rerun for documentation-only changes. Research artifact checks are recorded in [verification](mobile-app-20261031/research-verification.json).

## Blockers and exact next actions

| Blocker | Evidence / cause | Action, owner and completion check |
| --- | --- | --- |
| Full X article unavailable | Direct retrieval returned 403. | Research used the author's accessible companion and upstream sources. If exact thread coverage becomes necessary, Jason can provide its text; complete when compared with this summary. No authenticated cookie route was attempted. |
| First operational UI path incomplete | Local matrix: sale/stock/restart checks NOT RUN. | Existing SAVIA execution owner completes the already-scoped local pilot, with its own permissions. Complete on receipt + ledger + reload/restart proof. This research does not restart services or consume prior attempts. |
| Phone cannot use PC loopback as a remote backend | Inspected project has no verified mobile-accessible deployment. | Prepare a separate private-hosting candidate, identity design, cost and rollback for Jason's approval. Complete on trusted HTTPS login and role checks from both phones. No tunnel, firewall or certificate changes authorized here. |
| PWA scope and installation expectations not accepted | Only iPhone/Android support is confirmed. | Jason approves this first slice, or specifies that store-distributed binaries are required. Complete when architecture, scope and M01–M10 are accepted. |
| Whole-business workflows unknown | Finance and several modules lack inspected contracts. | After the first slice, observe the owner's daily workflow and prioritize the next costly task. Complete with agreed input, actor, output and exception for each module. |
| Native build environment not established | Current host is Windows; no Mac availability was established. | Relevant only if native distribution is selected. Jason identifies an approved Mac/build route; complete on signed device builds and tests. No purchase/signup proposed now. |

## Lesson applied

Older overview documents lag behind ongoing local work. Reading the current client and acceptance matrix prevented both underclaiming SQL progress and overclaiming operational readiness. For implementation, record source hashes and compare the next change with the actual working tree before writing code. The inspection manifest applies that correction now; it is not a runtime retest.

Next decision: approve the PWA first slice and M01–M10, subject to completing the existing local sale workflow. Reference-driven implementation waits for that approval under the shared evidence-first playbook. This document does not authorize deployment or expand pilot permissions.
