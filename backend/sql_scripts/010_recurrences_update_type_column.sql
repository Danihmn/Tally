BEGIN;

ALTER TABLE recurrences
    DROP COLUMN type;

ALTER TABLE recurrences
    ADD COLUMN type text NOT NULL DEFAULT 'EXPENSES'
        CHECK (type IN ('REVENUES', 'EXPENSES'));

ALTER TABLE recurrences
    ADD COLUMN payment_type text
        CHECK (payment_type IN ('DEBIT', 'CREDIT'));

COMMIT;