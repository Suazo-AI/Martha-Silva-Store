-- V011: Change Tracking on every remaining table the CP4 simulator replicates (ADR-001 D5, owner map).
-- V008 tracked six branch-owned tables. Credits, stock balances, returns and the V009 transfer
-- transition rows also move between nodes, so they are tracked too. No procedure changes.
-- tools/db/no_physical_delete.py now also guards these tables against DELETE and TRUNCATE.

ALTER TABLE [sales].[SaleReversals] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[SaleReversalLines] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [inventory].[StockBalances] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[Credits] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[CreditAllocations] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[CreditMovements] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[CreditRedemptions] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[TransferRequests] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[TransferApprovals] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[TransferCancellations] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[TransferDispatches] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [credits].[TransferReceipts] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
GO
