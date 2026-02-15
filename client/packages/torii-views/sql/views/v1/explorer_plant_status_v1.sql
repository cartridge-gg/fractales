-- Logical template view: explorer_plant_status_v1
CREATE VIEW explorer_plant_status_v1 AS
SELECT
  pn.plant_key,
  pn.hex_coordinate,
  pn.area_id,
  pn.plant_id,
  pn.species,
  pn.current_yield,
  pn.reserved_yield,
  pn.max_yield,
  pn.regrowth_rate,
  pn.stress_level,
  pn.health
FROM {{PlantNode}} pn;
