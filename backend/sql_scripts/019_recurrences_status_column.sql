ALTER TABLE recurrences
    ADD COLUMN status text NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'CANCELLED'));

DROP INDEX uq_financial_entries_recurrence_month;
CREATE UNIQUE INDEX uq_financial_entries_recurrence_month
    ON financial_entries (recurrence_id, reference_month)
    WHERE deleted_at IS NULL AND recurrence_id IS NOT NULL AND status <> 'CANCELLED';