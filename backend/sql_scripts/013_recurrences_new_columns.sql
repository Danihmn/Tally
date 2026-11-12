-- Recurrences: description, notes, source (MANUAL | AI), due day and household.
-- Financial entries: link to the recurrence that created them (one entry per recurrence and month).
BEGIN;

-- --------------------------------------------------------- recurrences
ALTER TABLE recurrences
    ADD COLUMN description text;

-- Backfill: the existing rows have no description
UPDATE recurrences
SET description = COALESCE(category, type)
WHERE description IS NULL;

ALTER TABLE recurrences
    ALTER COLUMN description SET NOT NULL;

ALTER TABLE recurrences
    ADD COLUMN notes text;

ALTER TABLE recurrences
    ADD COLUMN source text NOT NULL DEFAULT 'MANUAL'
        CHECK (source IN ('MANUAL', 'AI'));

ALTER TABLE recurrences
    ADD COLUMN due_day smallint
        CHECK (due_day BETWEEN 1 AND 31);

ALTER TABLE recurrences
    ADD COLUMN household_id uuid REFERENCES households (id) ON DELETE RESTRICT;

-- Backfill: the household of the user, or the first household when the user is NULL
UPDATE recurrences r
SET household_id = u.household_id
FROM users u
WHERE r.user_id = u.id;

UPDATE recurrences
SET household_id = (SELECT id FROM households ORDER BY created_at LIMIT 1)
WHERE household_id IS NULL;

ALTER TABLE recurrences
    ALTER COLUMN household_id SET NOT NULL;

CREATE INDEX idx_recurrences_household_id
    ON recurrences (household_id) WHERE deleted_at IS NULL;

-- --------------------------------------------------- financial_entries
ALTER TABLE financial_entries
    ADD COLUMN recurrence_id uuid REFERENCES recurrences (id) ON DELETE RESTRICT;

-- One active entry per recurrence and month
CREATE UNIQUE INDEX uq_financial_entries_recurrence_month
    ON financial_entries (recurrence_id, reference_month)
    WHERE deleted_at IS NULL AND recurrence_id IS NOT NULL;

COMMIT;
