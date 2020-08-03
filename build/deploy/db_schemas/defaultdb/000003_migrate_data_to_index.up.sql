BEGIN;

WITH compact_isa_cells AS
    ( SELECT identification_service_area_id,
             array_agg(cell_id) AS cell_ids
     FROM cells_identification_service_areas
     GROUP BY identification_service_area_id)
UPDATE identification_service_areas isa
SET cells = compact_isa_cells.cell_ids
FROM compact_isa_cells
WHERE isa.id = compact_isa_cells.identification_service_area_id
    AND cells IS NULL;

COMMIT;

BEGIN;

WITH compact_sub_cells AS
    ( SELECT subscription_id,
             array_agg(cell_id) AS cell_ids
     FROM cells_subscriptions
     GROUP BY subscription_id)
UPDATE subscriptions subs
SET cells = compact_sub_cells.cell_ids
FROM compact_sub_cells
WHERE subs.id = compact_sub_cells.subscription_id
    AND cells IS NULL;

COMMIT;

ALTER TABLE identification_service_areas ALTER COLUMN cells SET NOT NULL;
ALTER TABLE subscriptions ALTER COLUMN cells SET NOT NULL;
ALTER TABLE identification_service_areas ADD CONSTRAINT isa_cells_not_null CHECK (array_length(cells, 1) IS NOT NULL);
ALTER TABLE subscriptions ADD CONSTRAINT subs_cells_not_null CHECK (array_length(cells, 1) IS NOT NULL);
ALTER TABLE identification_service_areas DROP CONSTRAINT IF EXISTS cells_not_null;
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS cells_not_null;