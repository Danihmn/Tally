ALTER TABLE bank_accounts
    ADD COLUMN bank_code varchar(3) CHECK (bank_code ~ '^[0-9]{3}$')