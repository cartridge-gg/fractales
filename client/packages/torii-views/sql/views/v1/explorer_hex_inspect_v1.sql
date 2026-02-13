-- Logical template view: explorer_hex_inspect_v1
-- This should be expanded into concrete joins per Torii deployment mapping.
CREATE VIEW explorer_hex_inspect_v1 AS
SELECT
  h.coordinate AS hex_coordinate,
  h.biome,
  h.discovery_block,
  h.discoverer,
  h.area_count,
  ds.owner_adventurer_id,
  ds.current_energy_reserve,
  ds.decay_level,
  ds.last_decay_processed_block
FROM {{Hex}} h
LEFT JOIN {{HexDecayState}} ds ON ds.hex_coordinate = h.coordinate
WHERE h.is_discovered = 1;
