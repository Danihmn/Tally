BEGIN;

-- internal_transfer: NULL => not classified yet
-- SAME_HOUSEHOLD => transfer between different people of the same household
ALTER TABLE transactions
    ADD COLUMN internal_transfer                       varchar(25),
    ADD COLUMN internal_transfer_classification_source varchar(20);

ALTER TABLE transactions
    ADD CONSTRAINT transactions_internal_transfer_check
        CHECK (internal_transfer IN ('SAME_PERSON', 'SAME_HOUSEHOLD', 'NOT_INTERNAL_TRANSFER')),
    ADD CONSTRAINT transactions_internal_transfer_source_check
        CHECK (internal_transfer_classification_source IN ('MANUAL', 'AUTO')),
    ADD CONSTRAINT transactions_internal_transfer_consistency_check
        CHECK ((internal_transfer IS NULL AND internal_transfer_classification_source IS NULL)
            OR (internal_transfer IS NOT NULL AND internal_transfer_classification_source IS NOT NULL));

COMMIT;