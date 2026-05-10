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

ALTER TABLE owners
    ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE owners
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE vessels
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE vessels
    DROP CONSTRAINT IF EXISTS vessels_registration_number_key;

CREATE INDEX IF NOT EXISTS idx_owners_archived
    ON owners(archived);

CREATE INDEX IF NOT EXISTS idx_vessels_archived
    ON vessels(archived);

CREATE UNIQUE INDEX IF NOT EXISTS ux_vessels_registration_number_active
    ON vessels(LOWER(registration_number))
    WHERE archived = FALSE;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signature_url VARCHAR(2000);

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_sealed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_manifest_hash VARCHAR(64);

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_server_signature VARCHAR(128);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS content_type VARCHAR(255);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS uploaded_by_worker_id BIGINT;

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS storage_object_key VARCHAR(2000);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS sha256_hex VARCHAR(64);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS server_signature VARCHAR(128);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS upload_ip VARCHAR(128);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS upload_user_agent VARCHAR(1000);

CREATE INDEX IF NOT EXISTS idx_work_orders_evidence_sealed_at
    ON work_orders(evidence_sealed_at);

CREATE INDEX IF NOT EXISTS idx_work_order_attachments_uploaded_by_worker_id
    ON work_order_attachments(uploaded_by_worker_id);

CREATE INDEX IF NOT EXISTS idx_work_order_attachments_sha256_hex
    ON work_order_attachments(sha256_hex);

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS planned_clock_out TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS close_reminder_sent_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS auto_closed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS auto_close_reason VARCHAR(40);

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS clock_in_latitude DOUBLE PRECISION;

ALTER TABLE time_entries
    ADD COLUMN IF NOT EXISTS clock_in_longitude DOUBLE PRECISION;

ALTER TABLE workers
    ADD COLUMN IF NOT EXISTS last_missing_clock_in_reminder_date DATE;

CREATE TABLE IF NOT EXISTS registration_invitations (
    id BIGSERIAL PRIMARY KEY,
    worker_id BIGINT NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    consumed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_registration_invitations_worker_id
    ON registration_invitations(worker_id);

CREATE TABLE IF NOT EXISTS budget_events (
    id BIGSERIAL PRIMARY KEY,
    budget_id BIGINT NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    event_type VARCHAR(40) NOT NULL,
    actor_name VARCHAR(255) NOT NULL,
    actor_role VARCHAR(40) NOT NULL,
    event_note VARCHAR(2000),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_budget_events_budget_id_created_at
    ON budget_events(budget_id, created_at, id);

ALTER TABLE budgets
    ADD COLUMN IF NOT EXISTS origin_budget_id BIGINT;

ALTER TABLE budgets
    ADD COLUMN IF NOT EXISTS contact_name VARCHAR(255);

ALTER TABLE budgets
    ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255);

ALTER TABLE budgets
    ALTER COLUMN owner_id DROP NOT NULL;

ALTER TABLE budgets
    ALTER COLUMN vessel_id DROP NOT NULL;

UPDATE budgets
SET contact_name = COALESCE(contact_name, 'Cliente')
WHERE contact_name IS NULL;

UPDATE budgets
SET contact_email = COALESCE(contact_email, owners.email)
FROM owners
WHERE budgets.owner_id = owners.id
  AND budgets.contact_email IS NULL;

ALTER TABLE budgets
    ALTER COLUMN contact_email SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_budgets_origin_budget_id
    ON budgets(origin_budget_id);
