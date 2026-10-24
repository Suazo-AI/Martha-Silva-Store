# REA research checkpoint

REA 6.7.0 was installed from the official rea-agents npm package in an isolated tool directory with lifecycle scripts disabled. No MCP/global configuration changes were made.

Source: https://github.com/morluto/rea

The six artifact groups represent four merchant samples and two provider SDKs, not complete coverage of six websites. Berry and Young Skin have no static JS evidence in this pass. No payments, orders, endpoint calls or target-code execution were performed. No provider selected.

FINDINGS.md contains conclusions; analysis-index.json contains evidence IDs, hashes and coverage. Manifests map original public sources to sanitized-input hashes. A token-like literal was redacted before Tilopay analysis. Exact sanitized input snapshots are retained under inputs/, and full analyzer outputs under evidence/ as deterministic gzip files. These research artifacts are not included in the deployed dist/ directory. Public URLs can change, so a fresh download is not byte-identical evidence.

Reproduce in a separate workspace with Node 24.22.1 and procps-compatible ps:

    npm install --prefix ./tool --ignore-scripts --no-audit --no-fund --save-exact rea-agents@6.7.0
    ./tool/node_modules/.bin/rea analyze-javascript-application ./inputs/site --format json > evidence.json

Do not execute merchant files, install persistent interception certificates, enter card/customer data, or submit orders as part of research.
