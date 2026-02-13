-- Logical template view: explorer_hex_render_v1
-- Placeholders like {{Hex}} are resolved by mapping config in @gen-dungeon/torii-views.
CREATE VIEW explorer_hex_render_v1 AS
SELECT
  h.coordinate AS hex_coordinate,
  h.biome AS biome,
  ac.controller_adventurer_id AS owner_adventurer_id,
  COALESCE(ds.decay_level, 0) AS decay_level,
  CASE WHEN COALESCE(ds.decay_level, 0) >= 80 THEN 1 ELSE 0 END AS is_claimable,
  COALESCE(claims.active_claim_count, 0) AS active_claim_count,
  COALESCE(ap.adventurer_count, 0) AS adventurer_count,
  COALESCE(ps.plant_count, 0) AS plant_count
FROM {{Hex}} h
LEFT JOIN explorer_area_control_v1 ac ON ac.hex_coordinate = h.coordinate
LEFT JOIN {{HexDecayState}} ds ON ds.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT hex_coordinate, COUNT(*) AS active_claim_count
  FROM explorer_claim_active_v1
  GROUP BY hex_coordinate
) claims ON claims.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT current_hex AS hex_coordinate, COUNT(*) AS adventurer_count
  FROM explorer_adventurer_presence_v1
  GROUP BY current_hex
) ap ON ap.hex_coordinate = h.coordinate
LEFT JOIN (
  SELECT hex_coordinate, COUNT(*) AS plant_count
  FROM explorer_plant_status_v1
  GROUP BY hex_coordinate
) ps ON ps.hex_coordinate = h.coordinate
WHERE h.is_discovered = 1;
