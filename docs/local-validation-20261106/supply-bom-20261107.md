# SAVIA supply module UTF-8 encoding

The local Chrome → API → isolated SQL run on the baseline plus the encoding fix passed 34/34 checkpoints. The focused InternalSupplyUiTests case passed 1/1. The browser hash comparison rejected the leading UTF-8 BOM before the fix. The implementation removes those three bytes.

This checkpoint integrates the tested source change into local Tony. The integrated commit is subject to a fresh Docker run with synthetic data. Verify with dotnet test filtered to InternalSupplyUiTests and tests/golden-path/golden_path.py --mode browser --supply --stock-exception. Evidence stays in the local Docker validation handoff.

Scope is the local Linux runtime. Production, CI and SAVIATEST are outside this run.
