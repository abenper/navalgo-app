-- Seed NavalGO desde informes RIO SAJA / IRATI / IRO / TER.
-- Crea catalogo de componentes, plantillas, items de material y asigna
-- componentes a embarcaciones por nombre, creando las de Guardia Civil si faltan.
--
-- Notas:
-- - Las cantidades por motor no existen en el modelo actual; se guarda item/ref.
-- - Las asignaciones a embarcacion crean el barco de Guardia Civil si no existe.
-- - RIO IRATI e IRO tienen una incoherencia documental en generadores:
--   se crean todas las plantillas/componentes detectados. En IRATI se instala
--   el 17.5 EFKOZD porque el informe 132B lo identifica asi; en IRO se instala
--   Fisher Panda 1500i por consistencia del numero de serie.

BEGIN;

CREATE OR REPLACE FUNCTION ensure_material_product(
    p_article_name VARCHAR,
    p_reference_code VARCHAR
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT id INTO v_id
    FROM material_products
    WHERE LOWER(reference_code) = LOWER(TRIM(p_reference_code))
    ORDER BY id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO material_products (article_name, reference_code)
        VALUES (TRIM(p_article_name), TRIM(p_reference_code))
        RETURNING id INTO v_id;
    ELSE
        UPDATE material_products
        SET article_name = TRIM(p_article_name),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_material_template(
    p_name VARCHAR,
    p_description VARCHAR,
    p_template_type VARCHAR DEFAULT 'BASIC',
    p_base_template_name VARCHAR DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
    v_base_template_id BIGINT;
BEGIN
    IF p_base_template_name IS NOT NULL THEN
        SELECT id INTO v_base_template_id
        FROM material_checklist_templates
        WHERE name = p_base_template_name
        ORDER BY id
        LIMIT 1;
    END IF;

    SELECT id INTO v_id
    FROM material_checklist_templates
    WHERE LOWER(name) = LOWER(TRIM(p_name))
    ORDER BY id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO material_checklist_templates (
            name,
            description,
            template_type,
            base_template_id,
            created_at,
            updated_at
        ) VALUES (
            TRIM(p_name),
            p_description,
            TRIM(p_template_type),
            v_base_template_id,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        RETURNING id INTO v_id;
    ELSE
        UPDATE material_checklist_templates
        SET description = p_description,
            template_type = TRIM(p_template_type),
            base_template_id = v_base_template_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_material_template_item(
    p_template_name VARCHAR,
    p_article_name VARCHAR,
    p_reference_code VARCHAR,
    p_sort_order INTEGER
) RETURNS VOID AS $$
DECLARE
    v_template_id BIGINT;
    v_product_id BIGINT;
    v_item_id BIGINT;
BEGIN
    SELECT id INTO v_template_id
    FROM material_checklist_templates
    WHERE LOWER(name) = LOWER(TRIM(p_template_name))
    ORDER BY id
    LIMIT 1;

    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'Template not found: %', p_template_name;
    END IF;

    v_product_id := ensure_material_product(p_article_name, p_reference_code);

    SELECT id INTO v_item_id
    FROM material_checklist_template_items
    WHERE template_id = v_template_id
      AND LOWER(reference_code) = LOWER(TRIM(p_reference_code))
      AND LOWER(article_name) = LOWER(TRIM(p_article_name))
    ORDER BY id
    LIMIT 1;

    IF v_item_id IS NULL THEN
        INSERT INTO material_checklist_template_items (
            template_id,
            product_id,
            article_name,
            reference_code,
            sort_order
        ) VALUES (
            v_template_id,
            v_product_id,
            TRIM(p_article_name),
            TRIM(p_reference_code),
            p_sort_order
        );
    ELSE
        UPDATE material_checklist_template_items
        SET product_id = v_product_id,
            article_name = TRIM(p_article_name),
            sort_order = p_sort_order
        WHERE id = v_item_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_marine_component(
    p_type VARCHAR,
    p_name VARCHAR,
    p_manufacturer VARCHAR,
    p_model VARCHAR
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    SELECT id INTO v_id
    FROM marine_components
    WHERE type = TRIM(p_type)
      AND LOWER(name) = LOWER(TRIM(p_name))
      AND LOWER(COALESCE(model, '')) = LOWER(COALESCE(TRIM(p_model), ''))
    ORDER BY
      CASE
        WHEN LOWER(COALESCE(manufacturer, '')) = LOWER(COALESCE(TRIM(p_manufacturer), '')) THEN 0
        ELSE 1
      END,
      id
    LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO marine_components (type, name, manufacturer, model, archived)
        VALUES (TRIM(p_type), TRIM(p_name), TRIM(p_manufacturer), TRIM(p_model), FALSE)
        RETURNING id INTO v_id;
    ELSE
        UPDATE marine_components
        SET archived = FALSE,
            manufacturer = TRIM(p_manufacturer),
            model = TRIM(p_model)
        WHERE id = v_id;
    END IF;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION link_component_template(
    p_component_name VARCHAR,
    p_template_name VARCHAR
) RETURNS VOID AS $$
DECLARE
    v_component_id BIGINT;
    v_template_id BIGINT;
BEGIN
    SELECT id INTO v_component_id
    FROM marine_components
    WHERE LOWER(name) = LOWER(TRIM(p_component_name))
    ORDER BY id
    LIMIT 1;

    SELECT id INTO v_template_id
    FROM material_checklist_templates
    WHERE normalize_seed_lookup_text(name) = normalize_seed_lookup_text(p_template_name)
    ORDER BY id
    LIMIT 1;

    IF v_component_id IS NULL THEN
        RAISE EXCEPTION 'Component not found: %', p_component_name;
    END IF;
    IF v_template_id IS NULL THEN
        RAISE EXCEPTION 'Template not found: %', p_template_name;
    END IF;

    INSERT INTO marine_component_templates (component_id, template_id)
    VALUES (v_component_id, v_template_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION link_component_template_if_exists(
    p_component_name VARCHAR,
    p_template_name VARCHAR
) RETURNS VOID AS $$
DECLARE
    v_component_id BIGINT;
    v_template_id BIGINT;
BEGIN
    SELECT id INTO v_component_id
    FROM marine_components
    WHERE LOWER(name) = LOWER(TRIM(p_component_name))
    ORDER BY id
    LIMIT 1;

    SELECT id INTO v_template_id
    FROM material_checklist_templates
    WHERE normalize_seed_lookup_text(name) = normalize_seed_lookup_text(p_template_name)
    ORDER BY id
    LIMIT 1;

    IF v_component_id IS NULL THEN
        RAISE NOTICE 'Componente no encontrado para enlazar plantilla opcional: %', p_component_name;
        RETURN;
    END IF;

    IF v_template_id IS NULL THEN
        RAISE NOTICE 'Plantilla opcional no encontrada, se omite enlace: %', p_template_name;
        RETURN;
    END IF;

    INSERT INTO marine_component_templates (component_id, template_id)
    VALUES (v_component_id, v_template_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION normalize_seed_lookup_text(
    p_value VARCHAR
) RETURNS TEXT AS $$
BEGIN
    RETURN REGEXP_REPLACE(
        LOWER(
            TRANSLATE(
                COALESCE(p_value, ''),
                'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ',
                'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC'
            )
        ),
        '[^a-z0-9]+',
        '',
        'g'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION ensure_guardia_civil_owner()
RETURNS BIGINT AS $$
DECLARE
    v_owner_id BIGINT;
BEGIN
    SELECT id INTO v_owner_id
    FROM owners
    WHERE archived = FALSE
      AND (
          normalize_seed_lookup_text(display_name) = normalize_seed_lookup_text('Guardia Civil')
          OR normalize_seed_lookup_text(document_id) = normalize_seed_lookup_text('GUARDIA-CIVIL')
      )
    ORDER BY id
    LIMIT 1;

    IF v_owner_id IS NULL THEN
        INSERT INTO owners (
            type,
            display_name,
            document_id,
            phone,
            email,
            archived
        ) VALUES (
            'COMPANY',
            'Guardia Civil',
            'GUARDIA-CIVIL',
            NULL,
            NULL,
            FALSE
        )
        RETURNING id INTO v_owner_id;
    ELSE
        UPDATE owners
        SET type = 'COMPANY',
            display_name = 'Guardia Civil',
            archived = FALSE,
            archived_at = NULL
        WHERE id = v_owner_id;
    END IF;

    RETURN v_owner_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION guardia_civil_vessel_display_name(
    p_vessel_name VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
    v_normalized TEXT;
BEGIN
    v_normalized := normalize_seed_lookup_text(p_vessel_name);

    RETURN CASE v_normalized
        WHEN 'rioagueda' THEN 'Río Águeda'
        WHEN 'rioaragon' THEN 'Río Aragón'
        WHEN 'rioarba' THEN 'Río Arba'
        WHEN 'rioarlanza' THEN 'Río Arlanza'
        WHEN 'rioarra' THEN 'Río Arra'
        WHEN 'riobelelle' THEN 'Río Belelle'
        WHEN 'riobernesga' THEN 'Río Bernesga'
        WHEN 'riocabeiro' THEN 'Río Cabeiro'
        WHEN 'riocaudal' THEN 'Río Caudal'
        WHEN 'riocedena' THEN 'Río Cedena'
        WHEN 'riocervera' THEN 'Río Cervera'
        WHEN 'riocorneja' THEN 'Río Corneja'
        WHEN 'rioflumen' THEN 'Río Flumen'
        WHEN 'riogallo' THEN 'Río Gallo'
        WHEN 'riogenil' THEN 'Río Genil'
        WHEN 'rioguadalhorce' THEN 'Río Guadalhorce'
        WHEN 'rioguadiana' THEN 'Río Guadiana'
        WHEN 'rioirati' THEN 'Río Irati'
        WHEN 'rioiro' THEN 'Río Iro'
        WHEN 'riojiloca' THEN 'Río Jiloca'
        WHEN 'riomino' THEN 'Río Miño'
        WHEN 'rionacimiento' THEN 'Río Nacimiento'
        WHEN 'rionavia' THEN 'Río Navia'
        WHEN 'riosaja' THEN 'Río Saja'
        WHEN 'rioter' THEN 'Río Ter'
        WHEN 'riotietar' THEN 'Río Tiétar'
        WHEN 'rioulla' THEN 'Río Ulla'
        WHEN 's15' THEN 'S15'
        ELSE INITCAP(LOWER(TRIM(p_vessel_name)))
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION ensure_guardia_civil_vessel(
    p_vessel_name VARCHAR
) RETURNS BIGINT AS $$
DECLARE
    v_owner_id BIGINT;
    v_vessel_id BIGINT;
    v_display_name VARCHAR;
BEGIN
    WITH candidates AS (
        SELECT
            id,
            normalize_seed_lookup_text(name) AS normalized_name,
            normalize_seed_lookup_text(p_vessel_name) AS normalized_target
        FROM vessels
        WHERE archived = FALSE
    )
    SELECT id INTO v_vessel_id
    FROM candidates
    WHERE normalized_name = normalized_target
       OR normalized_name LIKE '%' || normalized_target || '%'
       OR normalized_target LIKE '%' || normalized_name || '%'
    ORDER BY
        CASE WHEN normalized_name = normalized_target THEN 0 ELSE 1 END,
        LENGTH(normalized_name),
        id
    LIMIT 1;

    v_owner_id := ensure_guardia_civil_owner();
    v_display_name := guardia_civil_vessel_display_name(p_vessel_name);

    IF v_vessel_id IS NULL THEN
        INSERT INTO vessels (
            name,
            registration_number,
            model,
            engine_count,
            owner_id,
            archived
        ) VALUES (
            v_display_name,
            NULL,
            'Guardia Civil',
            NULL,
            v_owner_id,
            FALSE
        )
        RETURNING id INTO v_vessel_id;

        RAISE NOTICE 'Embarcacion creada para Guardia Civil: %', v_display_name;
    ELSE
        UPDATE vessels
        SET owner_id = v_owner_id,
            archived = FALSE,
            archived_at = NULL,
            model = COALESCE(NULLIF(model, ''), 'Guardia Civil'),
            name = v_display_name
        WHERE id = v_vessel_id;
    END IF;

    RETURN v_vessel_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION install_vessel_component_if_vessel_exists(
    p_vessel_name VARCHAR,
    p_component_name VARCHAR,
    p_label VARCHAR,
    p_serial_number VARCHAR
) RETURNS VOID AS $$
DECLARE
    v_vessel_id BIGINT;
    v_component_id BIGINT;
    v_component RECORD;
    v_vessel_component_id BIGINT;
BEGIN
    WITH candidates AS (
        SELECT
            id,
            normalize_seed_lookup_text(name) AS normalized_name,
            normalize_seed_lookup_text(p_vessel_name) AS normalized_target
        FROM vessels
        WHERE archived = FALSE
    )
    SELECT id INTO v_vessel_id
    FROM candidates
    WHERE normalized_name = normalized_target
       OR normalized_name LIKE '%' || normalized_target || '%'
       OR normalized_target LIKE '%' || normalized_name || '%'
    ORDER BY
        CASE WHEN normalized_name = normalized_target THEN 0 ELSE 1 END,
        LENGTH(normalized_name),
        id
    LIMIT 1;

    IF v_vessel_id IS NULL THEN
        v_vessel_id := ensure_guardia_civil_vessel(p_vessel_name);
    END IF;

    SELECT * INTO v_component
    FROM marine_components
    WHERE LOWER(name) = LOWER(TRIM(p_component_name))
      AND archived = FALSE
    ORDER BY id
    LIMIT 1;

    IF v_component.id IS NULL THEN
        RAISE EXCEPTION 'Component not found: %', p_component_name;
    END IF;

    v_component_id := v_component.id;

    SELECT id INTO v_vessel_component_id
    FROM vessel_components
    WHERE vessel_id = v_vessel_id
      AND marine_component_id = v_component_id
      AND LOWER(label) = LOWER(TRIM(p_label))
    ORDER BY id
    LIMIT 1;

    IF v_vessel_component_id IS NULL THEN
        INSERT INTO vessel_components (
            vessel_id,
            marine_component_id,
            type,
            label,
            manufacturer,
            model,
            serial_number,
            current_hours
        ) VALUES (
            v_vessel_id,
            v_component_id,
            v_component.type,
            TRIM(p_label),
            v_component.manufacturer,
            v_component.model,
            NULLIF(TRIM(p_serial_number), ''),
            NULL
        )
        RETURNING id INTO v_vessel_component_id;
    ELSE
        UPDATE vessel_components
        SET serial_number = NULLIF(TRIM(p_serial_number), ''),
            type = v_component.type,
            manufacturer = v_component.manufacturer,
            model = v_component.model
        WHERE id = v_vessel_component_id;
    END IF;

    INSERT INTO vessel_component_templates (component_id, template_id)
    SELECT v_vessel_component_id, template_id
    FROM marine_component_templates
    WHERE component_id = v_component_id
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    -- Componentes base detectados.
    PERFORM ensure_marine_component('ENGINE', 'Motor D2862 LE463', 'MAN', 'D2862 LE463');
    PERFORM ensure_marine_component('ENGINE', 'Motor D2862 LE436', 'MAN', 'D2862 LE436');
    PERFORM ensure_marine_component('ENGINE', 'Motor D2842 LE422', 'MAN', 'D2842 LE422');
    PERFORM ensure_marine_component('ENGINE', 'Motor D2842 LE423', 'MAN', 'D2842 LE423');

    PERFORM ensure_marine_component('GEARBOX', 'Reductora ZF 3000', 'ZF', 'ZF 3000');
    PERFORM ensure_marine_component('GEARBOX', 'Reductora ZF 3055', 'ZF', 'ZF 3055');
    PERFORM ensure_marine_component('GEARBOX', 'Reductora ZF 2050', 'ZF', 'ZF 2050');

    PERFORM ensure_marine_component('GENERATOR', 'Generador 17.5 EFOZD', 'Kohler', '17.5 EFOZD');
    PERFORM ensure_marine_component('GENERATOR', 'Generador 17.5 EFKOZD', 'Kohler', '17.5 EFKOZD');
    PERFORM ensure_marine_component('GENERATOR', 'Generador 20 EFOZD', 'Kohler', '20 EFOZD');
    PERFORM ensure_marine_component('GENERATOR', 'Generador Panda 1500i', 'Fisher Panda', '1500i');
    PERFORM ensure_marine_component('GENERATOR', 'Generador Paguro 18000', 'Paguro', '18000');
    PERFORM ensure_marine_component('GENERATOR', 'Generador Onan', 'Onan', 'ONAN');

    -- Catalogo de hidrojets. Las plantillas vienen del seed de hidrojets escaneado.
    PERFORM ensure_marine_component('JET', 'Hidrojet HJ 274', 'Hamilton', 'HJ 274');
    PERFORM ensure_marine_component('JET', 'Hidrojet HJ 364', 'Hamilton', 'HJ 364');
    PERFORM ensure_marine_component('JET', 'Hidrojet HJ 403', 'Hamilton', 'HJ 403');
    PERFORM ensure_marine_component('JET', 'Hidrojet HM 461', 'Hamilton', 'HM 461');
    PERFORM ensure_marine_component('JET', 'Hidrojet HM 521', 'Hamilton', 'HM 521');
    PERFORM ensure_marine_component('JET', 'Hidrojet HM 571', 'Hamilton', 'HM 571');
    PERFORM ensure_marine_component('JET', 'Hidrojet HTX 42', 'Hamilton', 'HTX 42');
    PERFORM ensure_marine_component('JET', 'Hidrojet TD 490 HC', 'Castoldi', 'Turbodrive 490 H.C');
    PERFORM ensure_marine_component('JET', 'Hidrojet 40A3', 'Kamewa', '40A3');

    -- Plantillas MAN D2862 LE463.
    PERFORM ensure_material_template(
        'Revisión 115B: Motores MAN D2862 LE463',
        'Procedimientos: reglaje de valvulas; verificacion de correas; sustitucion de aceite y filtros; control de uniones. Intervalos vistos: 500, 1500, 2500, 3500 y 4500 h.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE463', 'Junta de culatin', '51.03905-0212', 10);
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE463', 'Filtro de aceite', '51.05504-0122', 20);
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE463', 'Aceite 10W40', '10W40', 30);

    PERFORM ensure_material_template(
        'Revisión 115C: Motores MAN D2862 LE463',
        'Procedimientos: reglaje de valvulas; correas; aceite y filtros; filtros de aire; limpieza prefiltro combustible; sistema MMDS/SFFR/EDC-7; bomba agua salada; filtros combustible y decantadores; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta de culatin', '51.03905-0186', 10);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Filtro de aceite', '51.05504-0138', 20);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Aceite 10W40', '10W40', 30);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Filtro de aire', '51.08401-6013', 40);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta intercooler', '51.96501-0346', 50);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta intercooler', '06.56930-2637', 60);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta prefiltro combustible', '51.96501-0544', 70);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Bomba de agua salada', '51.06500-7139', 80);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta bomba agua salada', '51.06901-0222', 90);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta a bloque', '51.96501-0746', 100);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta', '06.56343-2241', 110);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta bba calderin', '06.56930-2686', 120);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta refrigeracion', '06.56936-2733', 130);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Junta codo agua salada', '06.56936-2969', 140);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Filtro combustible', '51.12503-0069', 150);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Decantador', '51.12503-0052', 160);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Filtro combustible', '51.12503-0097', 170);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Decantador', '51.12503-6005', 180);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Impeller', '51.06506-0106', 190);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Reten', '51.06520-0088', 200);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE463', 'Reten aceite', '51.06520-0083', 210);

    PERFORM ensure_material_template(
        'Revisión 115D: Motores MAN D2862 LE463',
        'Procedimientos: reglaje de valvulas; aceite y filtros; filtros de aire; prefiltro combustible; limpieza enfriador aire; intercambiador de calor; refrigerante; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta de culatin', '51.03905-0186', 10);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Filtro de aceite', '51.05504-0138', 20);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Aceite bidon 208 L', '09.11001-0022', 30);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Filtro de aire', '51.08401-6013', 40);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta', '51.96501-0346', 50);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta', '06.56930-2637', 60);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta prefiltro combustible', '51.96501-0544', 70);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta', '51.09905-0114', 80);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta', '51.09905-0115', 90);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Junta', '51.09904-0029', 100);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56936-2733', 110);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56343-2241', 120);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56936-3607', 130);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56930-6411', 140);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56936-3036', 150);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56631-0106', 160);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56180-0716', 170);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anillo junta', '06.56930-2127', 180);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Anticongelante', '09.21001-0037', 190);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Tuberia refrigerante', '51.06303-0344', 200);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Pieza montaje', '51.06312-0054', 210);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Tuberia refrigerante', '51.06303-0345', 220);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Torica de mirilla', '06.56936-2355', 230);
    PERFORM ensure_material_template_item('Revisión 115D: Motores MAN D2862 LE463', 'Arandela de goma', '06.56631-0126', 240);

    -- Plantilla MAN D2862 LE436.
    PERFORM ensure_material_template(
        'Revisión 120C: Motores MAN D2862 LE436',
        'Procedimientos: sustitucion aceite y filtros; verificacion correas; comprobar tornillos del carter; control de uniones. Intervalos vistos: 1200, 2000, 3600, 4400 y 5200 h.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 120C: Motores MAN D2862 LE436', 'Filtro de aceite', '51.05504-0122', 10);
    PERFORM ensure_material_template_item('Revisión 120C: Motores MAN D2862 LE436', 'Aceite 10W40', '10W40', 20);

    PERFORM ensure_material_template(
        'Revisión 115C: Motores MAN D2862 LE436',
        'Procedimientos: reglaje de valvulas; correas; aceite y filtros; filtros de combustible y decantadores; filtros de aire; bomba de agua salada; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta de culatin', '51.03905-0212', 10);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Filtro de aceite', '51.05504-0138', 20);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Aceite 10W40', '10W40', 30);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Filtro combustible', '51.12503-0097', 40);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Decantador', '51.12503-6005', 50);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Filtro de aire', '51.08401-6013', 60);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta intercooler', '51.96501-0346', 70);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta intercooler', '06.56930-2637', 80);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Bomba de agua salada', '51.06500-7139', 90);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta bomba agua salada', '51.06901-0222', 100);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta a bloque', '51.96501-0746', 110);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta', '06.56343-2241', 120);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta bba calderin', '06.56930-2686', 130);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta refrigeracion', '06.56936-2733', 140);
    PERFORM ensure_material_template_item('Revisión 115C: Motores MAN D2862 LE436', 'Junta codo agua salada', '06.56936-2969', 150);

    PERFORM ensure_material_template(
        'Revisión 115B: Motores MAN D2862 LE436',
        'Procedimientos: reglaje de valvulas; correas; filtros de aire; aceite y filtros; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE436', 'Junta de culatin', '51.03905-0212', 10);
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE436', 'Filtro de aire', '51.08401-6013', 20);
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE436', 'Filtro de aceite', '51.05504-0138', 30);
    PERFORM ensure_material_template_item('Revisión 115B: Motores MAN D2862 LE436', 'Aceite 10W40', '10W40', 40);

    PERFORM ensure_material_template(
        'Revisión 120B: Motores MAN D2862 LE436',
        'Procedimientos: reglaje de valvulas; correas; filtros de aire; aceite y filtros; filtros de combustible y decantadores; carter; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Junta de culatin', '51.03905-0212', 10);
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Filtro de aire', '51.08401-6013', 20);
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Filtro de aceite', '51.05504-0138', 30);
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Aceite 10W40', '09.11001-0022', 40);
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Filtro combustible', '51.12503-0097', 50);
    PERFORM ensure_material_template_item('Revisión 120B: Motores MAN D2862 LE436', 'Filtro decantador', '51.12503-6005', 60);

    -- Plantillas MAN D2842 LE422.
    PERFORM ensure_material_template(
        'Revisión 114B: Motores MAN D2842 LE422',
        'Procedimientos: reglaje de valvulas; aceite y filtros; correas; filtros de aire; limpieza prefiltro combustible; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Junta de culatin', '51.03905-0190', 10);
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Filtro de aceite', '51.05504-0104', 20);
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Junta filtro', '06.56930-3809', 30);
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Aceite 10W40', '09.11001-0036', 40);
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Filtro de aire', '51.08301-0016', 50);
    PERFORM ensure_material_template_item('Revisión 114B: Motores MAN D2842 LE422', 'Filtro prefiltro combustible', '51.12503-0062', 60);

    PERFORM ensure_material_template(
        'Revisión 114F: Motores MAN D2842 LE422',
        'Procedimientos: reglaje de valvulas; aceite y filtros; filtros de aire; prefiltro combustible; compresiones; limpieza enfriador aire; intercambiador calor; culatas, valvulas, asientos y guias; turbos; waste-gate; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta de culatin', '51.03905-0190', 10);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Filtro de aceite', '51.05504-0104', 20);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta filtro', '06.56930-3809', 30);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Aceite 10W40', '09.11001-0036', 40);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Filtro de aire', '51.08301-0016', 50);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Filtro prefiltro combustible', '51.12503-0062', 60);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta lateral', '51.09905-0058N', 70);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta lateral', '51.09904-0048', 80);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta lateral', '51.09904-0047', 90);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta tubo', '51.08902-0200', 100);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Anillo junta', '06.56930-2686', 110);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta tubo', '06.56343-2241', 120);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Anillo junta', '06.56936-2733', 130);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta haz tubular', '06.56930-4388', 140);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta', '06.56939-0049', 150);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Anticongelante', '09.21001-0037', 160);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Asiento de admision', '51.03203-0374', 170);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Asiento de escape', '51.03203-0375', 180);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Guia de valvula', '51.03201-0126', 190);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Tornillo de culata', '51.90490-0041', 200);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Tornillo de culata', '51.90490-0042', 210);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Valvula de admision', '51.04101-0586', 220);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Valvula de escape', '51.04101-0775', 230);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Reten de valvula', '51.04902-0033', 240);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Juego descarbonizacion', '51.00900-6678', 250);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Kit reparacion turbos', 'SIN-REF-114F-KIT-TURBOS', 260);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta turbo', '51.96601-0383', 270);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta turbo', '51.96601-0386', 280);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Junta escape', '51.15901-0036', 290);
    PERFORM ensure_material_template_item('Revisión 114F: Motores MAN D2842 LE422', 'Tornillos escape', '51.90490-0037', 300);

    PERFORM ensure_material_template(
        'Revisión 118D: Motores MAN D2842 LE423',
        'Procedimientos: reglaje de valvulas; aceite y filtros; correas; filtros de aire; prefiltro combustible; intercambiador; enfriador de aire; refrigerante; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta de culatin', '51.03905-0190', 10);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Filtro de aceite', '51.05504-0104', 20);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta filtro', '06.56930-3809', 30);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Aceite 10W40', '09.11001-0036', 40);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Filtro de aire', '51.08301-0016', 50);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Anillo junta', '51.12503-0062', 60);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta salida a bomba', '06.56936-2733', 70);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta haz tubular', '06.56930-4388', 80);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta', '06.56939-0049', 90);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Anticongelante', '09.21001-0037', 100);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta lateral', '51.09905-0058N', 110);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta lateral', '51.09904-0048', 120);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta lateral', '51.09904-0047', 130);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta tubo', '51.08902-0200', 140);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Anillo junta bba agua salada', '06.56930-2686', 150);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Anillo junta lado turbo', '06.56343-2241', 160);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Anillo junta cuernos', '06.56936-2733', 170);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Torica retorno refrigerante', '06.56631-0237', 180);
    PERFORM ensure_material_template_item('Revisión 118D: Motores MAN D2842 LE423', 'Junta', '06.56930-6411', 190);

    -- Reductoras.
    PERFORM ensure_material_template(
        'Revisión 122B: Reductoras ZF 3000',
        'Procedimientos: aceite y filtro; comprobar presion aceite; reapriete; conexiones y apoyos; limpieza transmision; posicion cambio; lubricacion partes exteriores; anodos no lleva.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 122B: Reductoras ZF 3000', 'Filtro aceite', '0501 212 459 01', 10);
    PERFORM ensure_material_template_item('Revisión 122B: Reductoras ZF 3000', 'Aceite 1035 Petrel', '1035 Petrel', 20);

    PERFORM ensure_material_template(
        'Revisión 122B: Reductoras ZF 3055',
        'Procedimientos: aceite y filtro; comprobar presion aceite; reapriete; conexiones y apoyos; limpieza transmision; posicion cambio; lubricacion partes exteriores; anodos no lleva.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 122B: Reductoras ZF 3055', 'Filtro aceite', '0501 212 459 01', 10);
    PERFORM ensure_material_template_item('Revisión 122B: Reductoras ZF 3055', 'Aceite 1035 Petrel', '1035 Petrel', 20);

    PERFORM ensure_material_template(
        'Revisión 121B: Reductoras ZF 3055',
        'Procedimientos: aceite y filtro; reapriete; conexiones y apoyos; limpieza transmision; posicion cambio; lubricacion; nivel y presion aceite; limpieza enfriador.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 3055', 'Filtro aceite', '0501 212 459 01', 10);
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 3055', 'Aceite 1035 Petrel', '1035 Petrel', 20);
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 3055', 'Junta enfriador', '0634 313 136 01', 30);
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 3055', 'Junta enfriador', '0634 316 249 01', 40);
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 3055', 'Junta enfriador', '0634 313 732 01', 50);

    PERFORM ensure_material_template(
        'Revisión 121B: Reductoras ZF 2050',
        'Procedimientos: aceite y filtro; reapriete; conexiones y apoyos; limpieza transmision; posicion cambio; lubricacion; comprobar nivel y presion de aceite; anodos no lleva.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 2050', 'Filtro aceite', '0501 212 459 01', 10);
    PERFORM ensure_material_template_item('Revisión 121B: Reductoras ZF 2050', 'Aceite 1035 Petrel', '1035 Petrel', 20);

    -- Generadores Kohler 17.5.
    PERFORM ensure_material_template(
        'Revisión 132B: Generadores Kohler 17.5 EFKOZD',
        'Procedimientos: limpieza filtro aire; verificacion correas; drenaje filtro decantador; baterias; anodo zinc; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132B: Generadores Kohler 17.5 EFKOZD', 'Anodo', 'ED0090802840-S', 10);

    PERFORM ensure_material_template(
        'Revisión 132D: Generadores Kohler 17.5 EFOZD',
        'Procedimientos: aceite y filtros; filtro aire; correas; reglaje valvulas; arranque local/remoto; filtro decantador; baterias; filtro combustible; bomba agua salada; valvula retorno; codo mezclador; toberas; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Filtro aceite', 'GM47465', 10);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Elemento filtrante', 'GM24456', 30);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Correa alternador', '344829', 40);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Correa bba agua salada', '256503', 50);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Junta tapa balancines', 'GM35627', 60);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Filtro decantador', '2010PM', 70);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Filtro combustible', 'GM32359', 80);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Bba agua salada', 'GM104855', 90);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Junta codo de escape', '252929', 100);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Protector inyector', 'GM35450', 110);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Junta inyector', '252744', 120);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 17.5 EFOZD', 'Tobera', 'GM35567', 130);

    PERFORM ensure_material_template(
        'Revisión 132G: Generadores Kohler 17.5 EFOZD',
        'Procedimientos: aceite y filtros; correas; filtro decantador; anodo; filtro combustible; bomba agua salada; codo; toberas; intercambiador de calor; termostato; refrigerante; motor arranque; control uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Filtro aceite', 'ED0021752800-S', 10);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Correa', 'GM90645', 30);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Filtro decantador', '2010TM-OR', 40);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Anodo', 'ED0090802840-S', 50);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Filtro combustible', 'ED0021753200-S', 60);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Bba agua salada', 'GM104684', 70);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Junta codo de escape', '249905', 80);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Protector inyector', 'ED0046701430', 90);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Junta inyector', 'ED0046701750-S', 100);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Tobera', 'ED0065318550-S', 110);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Junta intercambiador', 'ED0012020260-S', 120);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Junta escape', 'ED0044201260-S', 130);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Termostato', 'ED0091950030-S', 140);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 17.5 EFOZD', 'Anticongelante', '1004/002', 150);

    PERFORM ensure_material_template(
        'Revisión 136D: Generadores Kohler 17.5 EFOZD',
        'Procedimientos: aceite y filtros; filtro aire; correas; reglaje valvulas; arranque; filtro decantador; baterias; filtro combustible; bomba agua salada; codo; toberas; control uniones. Documento parcial primera intervencion.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Filtro aceite', 'NR287/000155', 10);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Elemento filtrante', 'NRR-2602/0004034', 30);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Correa', 'NRR-2527/0004055', 40);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Junta tapa balancines', 'SIN-REF-136D-JUNTA-TAPA-BALANCINES', 50);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Filtro decantador', '2010PM', 60);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Filtro combustible', 'NR-277/0000220', 70);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Bba agua salada', 'SIN-REF-136D-BBA-AGUA-SALADA', 80);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Junta bba agua salada', 'SIN-REF-136D-JUNTA-BBA-AGUA-SALADA', 90);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Junta codo de escape', 'NRR-1028/0000051', 100);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Protector inyector', 'SIN-REF-136D-PROTECTOR-INYECTOR', 110);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Junta inyector', 'SIN-REF-136D-JUNTA-INYECTOR', 120);
    PERFORM ensure_material_template_item('Revisión 136D: Generadores Kohler 17.5 EFOZD', 'Tobera', 'SIN-REF-136D-TOBERA', 130);

    -- Fisher Panda 1500i.
    PERFORM ensure_material_template(
        'Revisión 131A: Generadores Fisher Panda 1500i',
        'Procedimientos: aceite y filtros; correas; arranque local/remoto; drenaje filtro decantador; conexiones electricas; reglaje valvulas; control uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 131A: Generadores Fisher Panda 1500i', 'Filtro aceite', '0001525', 10);
    PERFORM ensure_material_template_item('Revisión 131A: Generadores Fisher Panda 1500i', 'Aceite', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 131A: Generadores Fisher Panda 1500i', 'Junta tapa culata', '1G962-1452-2', 30);

    PERFORM ensure_material_template(
        'Revisión 131B: Generadores Fisher Panda 1500i',
        'Procedimientos: limpieza filtros aire; correas; arranque local/remoto; baterias; control de uniones.',
        'BASIC'
    );

    PERFORM ensure_material_template(
        'Revisión 132B: Generadores Fisher Panda 1500i',
        'Procedimientos: limpieza filtros aire; correas; arranque local/remoto; baterias; control de uniones.',
        'BASIC'
    );

    PERFORM ensure_material_template(
        'Revisión 132C: Generadores Fisher Panda 1500i',
        'Procedimientos: aceite y filtros; limpieza filtro aire; correas; arranque local/remoto; drenaje filtro decantador; baterias; anodos no tiene; control uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132C: Generadores Fisher Panda 1500i', 'Filtro aceite', '0001525', 10);
    PERFORM ensure_material_template_item('Revisión 132C: Generadores Fisher Panda 1500i', 'Aceite', '09.11001-0036', 20);

    PERFORM ensure_material_template(
        'Revisión 136B: Generadores Fisher Panda 1500i',
        'Procedimientos: aceite y filtros; valvula solenoide de arranque; correas; combustible; baterias; anodos no tiene; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 136B: Generadores Fisher Panda 1500i', 'Filtro aceite', 'NR287/000155', 10);
    PERFORM ensure_material_template_item('Revisión 136B: Generadores Fisher Panda 1500i', 'Aceite', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 136B: Generadores Fisher Panda 1500i', 'Filtro combustible', 'NR277/000220', 30);

    PERFORM ensure_material_template(
        'Revisión 136C: Generadores Fisher Panda 1500i',
        'Procedimientos: aceite y filtros; filtro aire; correas; reglaje valvulas; arranque; baterias; combustible; bomba agua salada; valvula paro; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Filtro aceite', 'NR-287/000155/610W21ESO1500', 10);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Elemento filtrante', 'NRR-4481/GM24456', 30);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Correa', 'NRR-2128/0000025', 40);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Junta tapa balancines', 'NRR-2528', 50);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Filtro combustible', 'NR-277/0000220', 60);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Bba agua salada', 'SIN-REF-136C-PANDA-BBA-AGUA-SALADA', 70);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Fisher Panda 1500i', 'Junta bba agua salada', 'NRR-3654', 80);

    PERFORM ensure_material_template(
        'Revisión 136C: Generadores Paguro 18000',
        'Procedimientos: aceite y filtros; filtro aire; correas; arranque; decantador; valvula solenoide; baterias; anodo; combustible; intercambiador; termostato; bomba agua salada; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Filtro aceite', 'ED0021752800-S', 10);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Aceite 8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Anodo', 'PAGAD40LO9080215', 30);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Filtro combustible', '175286', 40);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Junta intercambiador', 'ED0012020260-S', 50);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Junta escape', 'ED0044201260-S', 60);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Tapon', 'ED0090002780-S', 70);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Termostato', 'ED0091950030-S', 80);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Junta termostato', 'ED0044201220-S', 90);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Anticongelante', '09.21001-0037', 100);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Bomba agua salada', 'PAGAD40LO6584514', 110);
    PERFORM ensure_material_template_item('Revisión 136C: Generadores Paguro 18000', 'Junta bomba a bloque', 'AD40AN1092', 120);

    PERFORM ensure_material_template(
        'Revisión 134C: Generadores Onan',
        'Procedimientos: aceite y filtros; limpieza filtro aire; correas; arranque local/remoto; decantador; baterias; anodo; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 134C: Generadores Onan', 'Filtro aceite', '0185-5835', 10);
    PERFORM ensure_material_template_item('Revisión 134C: Generadores Onan', 'Aceite', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 134C: Generadores Onan', 'Anodo', '0130-4434', 30);

    PERFORM ensure_material_template(
        'Revisión 132B: Generadores Kohler 17.5 EFOZD',
        'Procedimientos: limpieza filtro aire; correas; drenaje filtro decantador; baterias; anodos no lleva; control de uniones.',
        'BASIC'
    );

    PERFORM ensure_material_template(
        'Revisión 132C: Generadores Kohler 17.5 EFOZD',
        'Procedimientos: aceite y filtros; filtro aire; correas; arranque local/remoto; decantador; baterias; anodos no tiene; control de uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132C: Generadores Kohler 17.5 EFOZD', 'Filtro aceite', 'GM47465', 10);
    PERFORM ensure_material_template_item('Revisión 132C: Generadores Kohler 17.5 EFOZD', 'Aceite', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 132C: Generadores Kohler 17.5 EFOZD', 'Elemento filtrante', 'GM24456', 30);

    -- Kohler 20 EFOZD.
    PERFORM ensure_material_template(
        'Revisión 132D: Generadores Kohler 20 EFOZD',
        'Procedimientos: aceite y filtros; filtro aire; correas; reglaje valvulas; arranque; filtro decantador; baterias; filtro combustible; bomba agua salada; codo; toberas; control uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Filtro aceite', 'GM47465', 10);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Elemento filtrante', '250902', 30);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Correa alternador', '344829', 40);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Correa bba agua salada', '256503', 50);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Junta tapa balancines', 'GM35593', 60);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Filtro decantador', 'R20P', 70);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Filtro combustible', 'GM32359', 80);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Bba agua salada', 'GM104855', 90);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Junta codo de escape', '256653', 100);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Protector inyector', 'GM35450', 110);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Junta inyector', '252744', 120);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Tobera', 'GM35567', 130);
    PERFORM ensure_material_template_item('Revisión 132D: Generadores Kohler 20 EFOZD', 'Sello', 'GM35506', 140);

    PERFORM ensure_material_template(
        'Revisión 132G: Generadores Kohler 20 EFOZD',
        'Procedimientos: aceite y filtros; filtro aire; correas; reglaje valvulas; arranque; filtro decantador; baterias; combustible; bomba agua salada; codo; toberas; intercambiador; termostato; refrigerante; motor arranque; control uniones.',
        'BASIC'
    );
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Filtro aceite', 'GM47465', 10);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Aceite 5,8 L', '09.11001-0036', 20);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Elemento filtrante', '250902', 30);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Correa alternador', '344829', 40);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Correa bba agua salada', '256503', 50);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta tapa balancines', 'GM35593', 60);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Filtro decantador', 'R20P', 70);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Filtro combustible', 'GM32359', 80);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Bba agua salada', 'GM104855', 90);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta codo de escape', '256653', 100);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Protector inyector', 'GM35450', 110);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta inyector', '252744', 120);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Tobera', 'GM35567', 130);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Sello', 'GM35506', 140);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta intercambiador', 'GM72405', 150);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta intercambiador', '252749', 160);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Toricas intercambiador', '252685', 170);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Tapon', '252748', 180);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta', '249865', 190);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Termostato', 'GM41963', 200);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Junta termostato', '229433', 210);
    PERFORM ensure_material_template_item('Revisión 132G: Generadores Kohler 20 EFOZD', 'Anticongelante', '1004/002', 220);

    -- Enlaces componente -> plantillas.
    PERFORM link_component_template('Motor D2862 LE463', 'Revisión 115B: Motores MAN D2862 LE463');
    PERFORM link_component_template('Motor D2862 LE463', 'Revisión 115C: Motores MAN D2862 LE463');
    PERFORM link_component_template('Motor D2862 LE463', 'Revisión 115D: Motores MAN D2862 LE463');
    PERFORM link_component_template('Motor D2862 LE436', 'Revisión 115B: Motores MAN D2862 LE436');
    PERFORM link_component_template('Motor D2862 LE436', 'Revisión 115C: Motores MAN D2862 LE436');
    PERFORM link_component_template('Motor D2862 LE436', 'Revisión 120B: Motores MAN D2862 LE436');
    PERFORM link_component_template('Motor D2862 LE436', 'Revisión 120C: Motores MAN D2862 LE436');
    PERFORM link_component_template('Motor D2842 LE422', 'Revisión 114B: Motores MAN D2842 LE422');
    PERFORM link_component_template('Motor D2842 LE422', 'Revisión 114F: Motores MAN D2842 LE422');
    PERFORM link_component_template('Motor D2842 LE423', 'Revisión 118D: Motores MAN D2842 LE423');

    PERFORM link_component_template('Reductora ZF 3000', 'Revisión 122B: Reductoras ZF 3000');
    PERFORM link_component_template('Reductora ZF 3055', 'Revisión 121B: Reductoras ZF 3055');
    PERFORM link_component_template('Reductora ZF 3055', 'Revisión 122B: Reductoras ZF 3055');
    PERFORM link_component_template('Reductora ZF 2050', 'Revisión 121B: Reductoras ZF 2050');

    PERFORM link_component_template('Generador 17.5 EFKOZD', 'Revisión 132B: Generadores Kohler 17.5 EFKOZD');
    PERFORM link_component_template('Generador 17.5 EFOZD', 'Revisión 132D: Generadores Kohler 17.5 EFOZD');
    PERFORM link_component_template('Generador 17.5 EFOZD', 'Revisión 132G: Generadores Kohler 17.5 EFOZD');
    PERFORM link_component_template('Generador 17.5 EFOZD', 'Revisión 136D: Generadores Kohler 17.5 EFOZD');
    PERFORM link_component_template('Generador 17.5 EFOZD', 'Revisión 132B: Generadores Kohler 17.5 EFOZD');
    PERFORM link_component_template('Generador 17.5 EFOZD', 'Revisión 132C: Generadores Kohler 17.5 EFOZD');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 131A: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 131B: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 132B: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 132C: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 136B: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador Panda 1500i', 'Revisión 136C: Generadores Fisher Panda 1500i');
    PERFORM link_component_template('Generador 20 EFOZD', 'Revisión 132D: Generadores Kohler 20 EFOZD');
    PERFORM link_component_template('Generador 20 EFOZD', 'Revisión 132G: Generadores Kohler 20 EFOZD');
    PERFORM link_component_template('Generador Paguro 18000', 'Revisión 136C: Generadores Paguro 18000');
    PERFORM link_component_template('Generador Onan', 'Revisión 134C: Generadores Onan');

    -- Enlaces opcionales para plantillas de hidrojets si ya se ejecuto su seed.
    PERFORM link_component_template_if_exists('Hidrojet HJ 274', 'REVISION 711A: HIDROJETS HJ 274');
    PERFORM link_component_template_if_exists('Hidrojet HJ 274', 'REVISION 711B: HIDROJETS HJ 274');
    PERFORM link_component_template_if_exists('Hidrojet HJ 364', 'REVISION 715A: HIDROJETS HJ 364');
    PERFORM link_component_template_if_exists('Hidrojet HJ 364', 'REVISION 715B: HIDROJETS HJ 364');
    PERFORM link_component_template_if_exists('Hidrojet HJ 403', 'REVISION 716A: HIDROJETS HJ 403');
    PERFORM link_component_template_if_exists('Hidrojet HJ 403', 'REVISION 716B: HIDROJETS HJ 403');
    PERFORM link_component_template_if_exists('Hidrojet HM 461', 'REVISION 717A: HIDROJETS HM 461');
    PERFORM link_component_template_if_exists('Hidrojet HM 461', 'REVISION 717B: HIDROJETS HM 461');
    PERFORM link_component_template_if_exists('Hidrojet HM 521', 'REVISION 718A: HIDROJETS HM 521');
    PERFORM link_component_template_if_exists('Hidrojet HM 521', 'REVISION 718B: HIDROJETS HM 521');
    PERFORM link_component_template_if_exists('Hidrojet HM 571', 'REVISION 719A: HIDROJETS HM 571');
    PERFORM link_component_template_if_exists('Hidrojet HM 571', 'REVISION 719B: HIDROJETS HM 571');
    PERFORM link_component_template_if_exists('Hidrojet HTX 42', 'REVISION 720A: HIDROJETS HTX 42');
    PERFORM link_component_template_if_exists('Hidrojet HTX 42', 'REVISION 720B: HIDROJETS HTX 42');
    PERFORM link_component_template_if_exists('Hidrojet TD 490 HC', 'REVISION 721A: HIDROJETS TD 490 HC');
    PERFORM link_component_template_if_exists('Hidrojet TD 490 HC', 'REVISION 721B: HIDROJETS TD 490 HC');
    PERFORM link_component_template_if_exists('Hidrojet 40A3', 'REVISION 722A: HIDROJETS 40A3');
    PERFORM link_component_template_if_exists('Hidrojet 40A3', 'REVISION 722B: HIDROJETS 40A3');

    -- Asignaciones a barcos. Si el barco no existe, se crea como Guardia Civil.
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Motor D2862 LE463', 'Babor', '71036588073650');
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Motor D2862 LE463', 'Estribor', '71036588043650');
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Reductora ZF 3000', 'Babor', '50034942');
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Reductora ZF 3000', 'Estribor', '50034941');
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Generador 17.5 EFOZD', 'Generador', 'SGM327G56');

    PERFORM install_vessel_component_if_vessel_exists('RIO IRATI', 'Motor D2862 LE463', 'Babor', '71063228106320');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRATI', 'Motor D2862 LE463', 'Estribor', '71063228206320');
    DELETE FROM vessel_components vc
    USING vessels v, marine_components mc
    WHERE vc.vessel_id = v.id
      AND vc.marine_component_id = mc.id
      AND normalize_seed_lookup_text(v.name) LIKE '%rioirati%'
      AND mc.name = 'Generador 17.5 EFOZD'
      AND vc.label = 'Generador'
      AND vc.serial_number = '337PGMKG0003';
    PERFORM install_vessel_component_if_vessel_exists('RIO IRATI', 'Generador 17.5 EFKOZD', 'Generador', '337PGMKG0003');

    PERFORM install_vessel_component_if_vessel_exists('RIO IRO', 'Motor D2862 LE436', 'Babor', '71067698086772');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRO', 'Motor D2862 LE436', 'Estribor', '71067688186772');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRO', 'Reductora ZF 3055', 'Babor', '50056005');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRO', 'Reductora ZF 3055', 'Estribor', '50053006');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRO', 'Generador Panda 1500i', 'Generador', '2401621');

    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Motor D2842 LE422', 'Babor', '69016971131686');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Motor D2842 LE422', 'Estribor', '69016580481650');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Reductora ZF 2050', 'Babor', '50027592');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Reductora ZF 2050', 'Estribor', '50027593');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Generador 20 EFOZD', 'Generador babor', '2249753');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Generador 20 EFOZD', 'Generador estribor', '2249754');

    PERFORM install_vessel_component_if_vessel_exists('RIO TIETAR', 'Motor D2862 LE436', 'Babor', '71070938127094');
    PERFORM install_vessel_component_if_vessel_exists('RIO TIETAR', 'Motor D2862 LE436', 'Estribor', '71070938047094');
    PERFORM install_vessel_component_if_vessel_exists('RIO TIETAR', 'Reductora ZF 3055', 'Babor', '50053167');
    PERFORM install_vessel_component_if_vessel_exists('RIO TIETAR', 'Reductora ZF 3055', 'Estribor', '50053166');
    PERFORM install_vessel_component_if_vessel_exists('RIO TIETAR', 'Generador Panda 1500i', 'Generador', 'SN2303052');

    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Motor D2862 LE436', 'Babor', '71063178206320');
    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Motor D2862 LE436', 'Estribor', '71063178086320');
    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Reductora ZF 3055', 'Babor', '50049734');
    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Reductora ZF 3055', 'Estribor', '50049734');
    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Generador Paguro 18000', 'Generador', '5219603540');

    PERFORM install_vessel_component_if_vessel_exists('RIO CEDENA', 'Motor D2842 LE423', 'Babor', '69020518022042');
    PERFORM install_vessel_component_if_vessel_exists('RIO CEDENA', 'Motor D2842 LE423', 'Estribor', '69020518072042');
    PERFORM install_vessel_component_if_vessel_exists('RIO CEDENA', 'Generador Onan', 'Generador', 'A040596082');

    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Motor D2862 LE463', 'Babor', '71037048043695');
    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Motor D2862 LE463', 'Estribor', '71037048153695');
    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Reductora ZF 3000', 'Babor', '50035263');
    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Reductora ZF 3000', 'Estribor', '50035262');
    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Generador 17.5 EFOZD', 'Generador', 'SGM327WG9');

    -- Hidrojets por embarcacion segun relacion Guardia Civil - Lote III Zona Sur.
    -- La hoja aporta fabricante/modelo, pero no numero de serie ni cantidad por banda.
    PERFORM install_vessel_component_if_vessel_exists('RIO FLUMEN', 'Hidrojet HTX 42', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO BELELLE', 'Hidrojet 40A3', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO CEDENA', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO NAVIA', 'Hidrojet HM 521', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO GUADIANA', 'Hidrojet HM 571', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO NACIMIENTO', 'Hidrojet HM 521', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO JILOCA', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO AGUEDA', 'Hidrojet 40A3', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO IRATI', 'Hidrojet HTX 42', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO ULLA', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO CAUDAL', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO BERNESGA', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('S15', 'Hidrojet HJ 274', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO ARLANZA', 'Hidrojet HM 571', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO CABEIRO', 'Hidrojet HM 571', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO GENIL', 'Hidrojet HM 461', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO ARAGON', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO CORNEJA', 'Hidrojet HTX 42', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO SAJA', 'Hidrojet HM 521', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO TER', 'Hidrojet HM 461', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO ARBA', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO GALLO', 'Hidrojet HJ 403', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO GUADALHORCE', 'Hidrojet 40A3', 'Jet', '');
    PERFORM install_vessel_component_if_vessel_exists('RIO CERVERA', 'Hidrojet HJ 403', 'Jet', '');
END;
$$;

-- Comprobacion rapida tras ejecutar:
-- SELECT mc.type, mc.manufacturer, mc.model, mc.name, COUNT(mct.template_id) AS plantillas
-- FROM marine_components mc
-- LEFT JOIN marine_component_templates mct ON mct.component_id = mc.id
-- WHERE mc.name IN (
--   'Motor D2862 LE463', 'Motor D2862 LE436', 'Motor D2842 LE422',
--   'Reductora ZF 3000', 'Reductora ZF 3055', 'Reductora ZF 2050',
--   'Generador 17.5 EFOZD', 'Generador 17.5 EFKOZD', 'Generador 20 EFOZD',
--   'Generador Panda 1500i',
--   'Hidrojet HJ 274', 'Hidrojet HJ 364', 'Hidrojet HJ 403',
--   'Hidrojet HM 461', 'Hidrojet HM 521', 'Hidrojet HM 571',
--   'Hidrojet HTX 42', 'Hidrojet TD 490 HC', 'Hidrojet 40A3'
-- )
-- GROUP BY mc.type, mc.manufacturer, mc.model, mc.name
-- ORDER BY mc.type, mc.manufacturer, mc.model;
--
-- SELECT v.name AS embarcacion, vc.type, vc.label, vc.manufacturer, vc.model, vc.serial_number
-- FROM vessel_components vc
-- JOIN vessels v ON v.id = vc.vessel_id
-- WHERE LOWER(v.name) IN ('rio saja', 'rio irati', 'rio iro', 'rio ter', 'rio flumen', 'rio cedena', 'rio navia')
-- ORDER BY v.name, vc.type, vc.label;

COMMIT;
