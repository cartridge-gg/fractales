-- Logical template view: explorer_area_control_v1
CREATE VIEW explorer_area_control_v1 AS
SELECT
  ha.hex_coordinate,
  MIN(ha.area_id) AS control_area_id,
  MAX(ao.owner_adventurer_id) AS controller_adventurer_id,
  COUNT(*) AS area_count,
  CASE
    WHEN COUNT(DISTINCT ao.owner_adventurer_id) <= 1 THEN 1
    ELSE 0
  END AS ownership_consistent
FROM {{HexArea}} ha
LEFT JOIN {{AreaOwnership}} ao ON ao.area_id = ha.area_id
WHERE ha.is_discovered = 1
GROUP BY ha.hex_coordinate;
