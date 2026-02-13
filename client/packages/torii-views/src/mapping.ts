export interface ToriiPhysicalTableMapping {
  Hex: string;
  HexArea: string;
  AreaOwnership: string;
  HexDecayState: string;
  ClaimEscrow: string;
  Adventurer: string;
  PlantNode: string;
  HarvestReservation: string;
  EventLog: string;
}

export const defaultToriiMapping: ToriiPhysicalTableMapping = {
  Hex: "world_hex",
  HexArea: "world_hex_area",
  AreaOwnership: "ownership_area_ownership",
  HexDecayState: "economics_hex_decay_state",
  ClaimEscrow: "economics_claim_escrow",
  Adventurer: "adventurer_adventurer",
  PlantNode: "harvesting_plant_node",
  HarvestReservation: "harvesting_harvest_reservation",
  EventLog: "event_log"
};
