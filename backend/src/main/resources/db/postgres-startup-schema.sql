-- Startup-safe PostgreSQL schema reconciliation for recent vessel fields.
-- Keep this file limited to simple DDL statements that Spring SQL init can parse.

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
