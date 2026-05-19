BEGIN;

ALTER TABLE workers
    ADD COLUMN IF NOT EXISTS phone_prefix VARCHAR(8);

ALTER TABLE workers
    ADD COLUMN IF NOT EXISTS phone VARCHAR(32);

-- Rellena primero los trabajadores existentes con datos reales antes de
-- ejecutar los SET NOT NULL. Ejemplo:
-- UPDATE workers
-- SET phone_prefix = '+34',
--     phone = '600000000'
-- WHERE id = 123;

ALTER TABLE workers
    ALTER COLUMN phone_prefix SET NOT NULL;

ALTER TABLE workers
    ALTER COLUMN phone SET NOT NULL;

COMMIT;
