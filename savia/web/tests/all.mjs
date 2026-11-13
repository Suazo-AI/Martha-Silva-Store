// Entry point so `node --test savia/web/tests/` works: Node 24 resolves the
// directory through package.json "main" instead of globbing it.
import './money.test.mjs';
import './scan.test.mjs';
import './logic.test.mjs';
import './api-contract.test.mjs';
import './payments.test.mjs';
import './returns.test.mjs';
import './roles.test.mjs';
import './receipt.test.mjs';
import './date-focus.test.mjs';

import './catalog-ticket.test.mjs';
