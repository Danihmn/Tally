BEGIN;

ALTER TABLE users
    ADD COLUMN last_name text;

ALTER TABLE users
    ADD COLUMN surname text;

COMMIT;