BEGIN;

-- Permite el nuevo rol COMERCIAL sin tocar los usuarios existentes.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_workers_role'
    ) THEN
        ALTER TABLE workers DROP CONSTRAINT ck_workers_role;
    END IF;
END $$;

ALTER TABLE workers
    ADD CONSTRAINT ck_workers_role
    CHECK (role IN ('ADMIN', 'COMERCIAL', 'WORKER'));

-- Acelera las comprobaciones de correo de cliente sin imponer un UNIQUE duro
-- sobre producción, para no romper datos históricos si hubiera casos antiguos.
CREATE INDEX IF NOT EXISTS idx_owners_email_lower
    ON owners (LOWER(email));

COMMIT;
