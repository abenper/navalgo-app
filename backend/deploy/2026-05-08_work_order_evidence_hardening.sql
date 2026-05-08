BEGIN;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signature_url VARCHAR(2000);

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS client_signed_at TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_sealed_at TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_manifest_hash VARCHAR(64);

ALTER TABLE work_orders
    ADD COLUMN IF NOT EXISTS evidence_server_signature VARCHAR(128);

CREATE INDEX IF NOT EXISTS idx_work_orders_evidence_sealed_at
    ON work_orders(evidence_sealed_at);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS content_type VARCHAR(255);

ALTER TABLE work_order_attachments
    ADD COLUMN IF NOT EXISTS uploaded_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

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

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_wo_attachments_uploaded_by_worker'
    ) THEN
        ALTER TABLE work_order_attachments
            ADD CONSTRAINT fk_wo_attachments_uploaded_by_worker
            FOREIGN KEY (uploaded_by_worker_id) REFERENCES workers(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_work_order_attachments_uploaded_by_worker_id
    ON work_order_attachments(uploaded_by_worker_id);

CREATE INDEX IF NOT EXISTS idx_work_order_attachments_sha256_hex
    ON work_order_attachments(sha256_hex);

COMMIT;
