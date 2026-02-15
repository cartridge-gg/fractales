-- Logical template view: explorer_adventurer_presence_v1
CREATE VIEW explorer_adventurer_presence_v1 AS
SELECT
  adv.adventurer_id,
  adv.owner,
  adv.is_alive,
  adv.current_hex,
  adv.energy,
  adv.activity_locked_until
FROM {{Adventurer}} adv;
