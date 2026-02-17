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
-- ACTIVE filtering uses the canonical enum code for ACTIVE claims.
-- Expiry filtering is applied by proxy query contracts with head-block context.
WHERE ce.status = 1;
