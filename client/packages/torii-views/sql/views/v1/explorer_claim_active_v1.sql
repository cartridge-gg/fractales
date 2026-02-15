-- Logical template view: explorer_claim_active_v1
CREATE VIEW explorer_claim_active_v1 AS
SELECT
  ce.hex_coordinate,
  ce.claim_id,
  ce.claimant_adventurer_id,
  ce.energy_locked,
  ce.created_block,
  ce.expiry_block
FROM {{ClaimEscrow}} ce
-- ACTIVE/non-expired filtering should be applied in deployment mappings
-- where enum encoding and current-head semantics are available.
;
