# Portable evidence hashes

INTEGRATION.json.sha256 uses canonical LF for UTF-8 .json, .md, .mjs and .patch
files: replace CRLF with LF, without other changes. All other files use raw bytes.
This is portable content verification, not a claim that working-tree CRLF and
Git-blob LF bytes have identical raw hashes. Source-byte hashes inside historical
browser results and frozen RESULT.json remain original runtime bytes.
Use the recorded original worker worktree or documented line-ending normalization
to verify those historical raw hashes. No frozen worker record was rewritten.

The area .gitattributes keeps published JSON, Markdown and patch files at LF.
For the original worker patch, extract its Git blob in binary mode to a file
before git apply --check in a disposable checkout at the recorded base.
Do not pipe it through a text encoder. Do not apply mutation patches to Tony.

Raw logs are outside the public package. In INTEGRATION.json, archivedLog records
point to the exact original path, SHA256 and external archivePath. The public
package contains reviewed structured totals instead of raw logs.

Mutation import has an explicit source-to-public map in mutations/IMPORT.json.
Its frozen RESULT.json records raw original worker artifacts. The public report
is primary-authored; worker-README.md retains the original report. Public M03.patch
removes indentation on two blank added lines to pass normal whitespace checks.
The exact original patch is privately archived with its SHA256. This derivative
reconstructs semantically identical code, not the recorded raw mutant bytes.
Only the original patch reconstructs the exact recorded raw bytes. No observed
run is attributed to the portable derivative. No product file was modified.
