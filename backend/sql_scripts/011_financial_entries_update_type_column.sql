BEGIN;

ALTER TABLE financial_entries
    DROP COLUMN type;

ALTER TABLE financial_entries
    ADD COLUMN type text NOT NULL DEFAULT 'EXPENSES'
        CHECK (type IN ('REVENUES', 'EXPENSES'));

ALTER TABLE financial_entries
    ADD COLUMN payment_type text
        CHECK (payment_type IN ('DEBIT', 'CREDIT'));

COMMIT;