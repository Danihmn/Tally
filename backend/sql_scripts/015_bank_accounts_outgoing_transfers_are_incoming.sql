-- outgoing_transfers_are_income: the bank does not report the money that comes in to this
-- account (a salary account, for example), so a transfer out of it to the same person is
-- the only trace of that income.
-- In the internal transfers classification, for a SAME_PERSON transfer that leaves this account:
--   the CREDIT (in the other account) => NOT_INTERNAL_TRANSFER: it counts as revenue;
--   the DEBIT (in this account)       => SAME_PERSON: it stays out of the expenses.
BEGIN;

ALTER TABLE bank_accounts
    ADD COLUMN outgoing_transfers_are_income boolean NOT NULL DEFAULT false;

COMMIT;
