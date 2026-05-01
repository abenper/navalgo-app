-- Startup-safe PostgreSQL schema reconciliation for recent vessel fields.
-- This runs before Hibernate validation in the postgres profile.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'vessels'
          AND column_name = 'engine_serial_number'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'vessels'
          AND column_name = 'engine_serial_numbers'
    ) THEN
        ALTER TABLE vessels RENAME COLUMN engine_serial_number TO engine_serial_numbers;
    END IF;
END $$;

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS engine_labels VARCHAR(1000);

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS engine_serial_numbers VARCHAR(1000);

ALTER TABLE vessels
    ALTER COLUMN engine_serial_numbers TYPE VARCHAR(1000);

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS jet_labels VARCHAR(1000);

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS jet_serial_numbers VARCHAR(1000);

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS gearbox_labels VARCHAR(1000);

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS gearbox_serial_numbers VARCHAR(1000);

ALTER TABLE vessels
    DROP COLUMN IF EXISTS engine_serial_number;
