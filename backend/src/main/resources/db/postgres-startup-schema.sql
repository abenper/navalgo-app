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

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signature_url VARCHAR(2000);

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS planned_clock_out TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS close_reminder_sent_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS auto_closed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS auto_close_reason VARCHAR(40);

ALTER TABLE workers
    ADD COLUMN IF NOT EXISTS last_missing_clock_in_reminder_date DATE;
