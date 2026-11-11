-- 008_households.sql
-- Multi-tenancy: every user belongs to one household.
BEGIN;

-- ---------------------------------------------------------- households
CREATE TABLE households
(
    id         uuid PRIMARY KEY     DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- --------------------------------------------------------------- users
ALTER TABLE users
    ADD COLUMN household_id uuid REFERENCES households (id) ON DELETE RESTRICT;

-- Backfill: the existing users share ONE household.
INSERT INTO households DEFAULT
VALUES;

UPDATE users
SET household_id = (SELECT id FROM households ORDER BY created_at LIMIT 1);

ALTER TABLE users
    ALTER COLUMN household_id SET NOT NULL;

CREATE INDEX idx_users_household_id ON users (household_id);

-- ------------------------------------------------------ bank_accounts
ALTER TABLE bank_accounts
    ADD COLUMN household_id uuid REFERENCES households (id) ON DELETE RESTRICT;

UPDATE bank_accounts ba
SET household_id = u.household_id
FROM pluggy_items pi
         JOIN users u ON u.id = pi.user_id
WHERE ba.pluggy_item_id = pi.id;

ALTER TABLE bank_accounts
    ALTER COLUMN household_id SET NOT NULL;

CREATE INDEX idx_bank_accounts_household_id ON bank_accounts (household_id);

-- -------------------------------------------------------- transactions
ALTER TABLE transactions
    ADD COLUMN household_id uuid REFERENCES households (id) ON DELETE RESTRICT;

UPDATE transactions t
SET household_id = ba.household_id
FROM bank_accounts ba
WHERE t.bank_account_id = ba.id;

ALTER TABLE transactions
    ALTER COLUMN household_id SET NOT NULL;

CREATE INDEX idx_transactions_household_date ON transactions (household_id, date DESC);

-- ---------------------------------------------------- financial_entries
ALTER TABLE financial_entries
    ADD COLUMN household_id uuid REFERENCES households (id) ON DELETE RESTRICT;

UPDATE financial_entries fe
SET household_id = u.household_id
FROM users u
WHERE fe.user_id = u.id;

ALTER TABLE financial_entries
    ALTER COLUMN household_id SET NOT NULL;

CREATE INDEX idx_financial_entries_household_month
    ON financial_entries (household_id, reference_month) WHERE deleted_at IS NULL;

COMMIT;