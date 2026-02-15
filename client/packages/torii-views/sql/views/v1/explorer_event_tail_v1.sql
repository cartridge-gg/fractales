-- Logical template view: explorer_event_tail_v1
CREATE VIEW explorer_event_tail_v1 AS
SELECT
  ev.block_number,
  ev.tx_index,
  ev.event_index,
  ev.event_name,
  ev.hex_coordinate,
  ev.adventurer_id,
  ev.payload_json
FROM {{EventLog}} ev
ORDER BY ev.block_number DESC, ev.tx_index DESC, ev.event_index DESC;
