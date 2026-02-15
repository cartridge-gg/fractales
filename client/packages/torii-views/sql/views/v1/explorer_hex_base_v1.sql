-- Logical template view: explorer_hex_base_v1
CREATE VIEW explorer_hex_base_v1 AS
SELECT
  h.coordinate AS hex_coordinate,
  h.biome,
  h.discovery_block,
  h.discoverer,
  h.area_count,
  COALESCE(ds.decay_level, 0) AS decay_level,
  COALESCE(ds.current_energy_reserve, 0) AS current_energy_reserve,
  COALESCE(ds.last_decay_processed_block, 0) AS last_decay_processed_block,
  ds.owner_adventurer_id
FROM {{Hex}} h
LEFT JOIN {{HexDecayState}} ds ON ds.hex_coordinate = h.coordinate
WHERE h.is_discovered = 1;
