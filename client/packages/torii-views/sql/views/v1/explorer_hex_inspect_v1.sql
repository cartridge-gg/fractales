-- Logical template view: explorer_hex_inspect_v1
-- This should be expanded into concrete joins per Torii deployment mapping.
CREATE VIEW explorer_hex_inspect_v1 AS
SELECT
  h.coordinate AS hex_coordinate,
  h.biome,
  h.discovery_block,
  h.discoverer,
  h.area_count,
  ha.area_id,
  ha.area_index,
  ha.area_type,
  ha.is_discovered AS area_discovered,
  ao.owner_adventurer_id,
  ao.claim_block,
  ds.owner_adventurer_id,
  ds.current_energy_reserve,
  ds.decay_level,
  ds.last_decay_processed_block,
  ds.claimable_since_block,
  ce.claim_id,
  ce.claimant_adventurer_id,
  ce.energy_locked,
  ce.created_block AS claim_created_block,
  ce.expiry_block AS claim_expiry_block,
  ce.status AS claim_status,
  pn.plant_key,
  pn.area_id AS plant_area_id,
  pn.plant_id,
  pn.species,
  pn.current_yield,
  pn.reserved_yield,
  pn.max_yield,
  pn.regrowth_rate,
  pn.health,
  pn.stress_level,
  hr.reservation_id,
  hr.adventurer_id AS reservation_adventurer_id,
  hr.reserved_amount,
  hr.created_block AS reservation_created_block,
  hr.expiry_block AS reservation_expiry_block,
  hr.status AS reservation_status,
  adv.adventurer_id,
  adv.owner AS adventurer_owner,
  adv.current_hex,
  adv.energy AS adventurer_energy,
  adv.is_alive
FROM {{Hex}} h
LEFT JOIN {{HexArea}} ha ON ha.hex_coordinate = h.coordinate
LEFT JOIN {{AreaOwnership}} ao ON ao.area_id = ha.area_id
LEFT JOIN {{HexDecayState}} ds ON ds.hex_coordinate = h.coordinate
LEFT JOIN {{ClaimEscrow}} ce ON ce.hex_coordinate = h.coordinate
LEFT JOIN {{PlantNode}} pn ON pn.hex_coordinate = h.coordinate
LEFT JOIN {{HarvestReservation}} hr ON hr.plant_key = pn.plant_key
LEFT JOIN {{Adventurer}} adv ON adv.current_hex = h.coordinate
WHERE h.is_discovered = 1;
