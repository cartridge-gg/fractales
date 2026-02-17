import type { SchemaType as ISchemaType } from "@dojoengine/sdk";

import { CairoCustomEnum, BigNumberish } from 'starknet';

// Type definition for `dojo_starter::models::adventurer::Adventurer` struct
export interface Adventurer {
	adventurer_id: BigNumberish;
	owner: string;
	name: BigNumberish;
	energy: BigNumberish;
	max_energy: BigNumberish;
	current_hex: BigNumberish;
	activity_locked_until: BigNumberish;
	is_alive: boolean;
}

// Type definition for `dojo_starter::models::construction::ConstructionBuildingNode` struct
export interface ConstructionBuildingNode {
	area_id: BigNumberish;
	hex_coordinate: BigNumberish;
	owner_adventurer_id: BigNumberish;
	building_type: BigNumberish;
	tier: BigNumberish;
	condition_bp: BigNumberish;
	upkeep_reserve: BigNumberish;
	last_upkeep_block: BigNumberish;
	is_active: boolean;
}

// Type definition for `dojo_starter::models::construction::ConstructionMaterialEscrow` struct
export interface ConstructionMaterialEscrow {
	project_id: BigNumberish;
	item_id: BigNumberish;
	quantity: BigNumberish;
}

// Type definition for `dojo_starter::models::construction::ConstructionProject` struct
export interface ConstructionProject {
	project_id: BigNumberish;
	adventurer_id: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	building_type: BigNumberish;
	target_tier: BigNumberish;
	start_block: BigNumberish;
	completion_block: BigNumberish;
	energy_staked: BigNumberish;
	status: ConstructionProjectStatusEnum;
}

// Type definition for `dojo_starter::models::deaths::DeathRecord` struct
export interface DeathRecord {
	adventurer_id: BigNumberish;
	owner: string;
	death_block: BigNumberish;
	death_cause: BigNumberish;
	inventory_lost_hash: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::AdventurerEconomics` struct
export interface AdventurerEconomics {
	adventurer_id: BigNumberish;
	energy_balance: BigNumberish;
	total_energy_spent: BigNumberish;
	total_energy_earned: BigNumberish;
	last_regen_block: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::ClaimEscrow` struct
export interface ClaimEscrow {
	claim_id: BigNumberish;
	hex_coordinate: BigNumberish;
	claimant_adventurer_id: BigNumberish;
	energy_locked: BigNumberish;
	created_block: BigNumberish;
	expiry_block: BigNumberish;
	status: ClaimEscrowStatusEnum;
}

// Type definition for `dojo_starter::models::economics::ConversionRate` struct
export interface ConversionRate {
	item_type: BigNumberish;
	current_rate: BigNumberish;
	base_rate: BigNumberish;
	last_update_block: BigNumberish;
	units_converted_in_window: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::EconomyAccumulator` struct
export interface EconomyAccumulator {
	epoch: BigNumberish;
	total_sources: BigNumberish;
	total_sinks: BigNumberish;
	new_hexes: BigNumberish;
	deaths: BigNumberish;
	mints: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::EconomyEpochSnapshot` struct
export interface EconomyEpochSnapshot {
	epoch: BigNumberish;
	total_sources: BigNumberish;
	total_sinks: BigNumberish;
	net_energy: BigNumberish;
	new_hexes: BigNumberish;
	deaths: BigNumberish;
	mints: BigNumberish;
	finalized_at_block: BigNumberish;
	is_finalized: boolean;
}

// Type definition for `dojo_starter::models::economics::HexDecayState` struct
export interface HexDecayState {
	hex_coordinate: BigNumberish;
	owner_adventurer_id: BigNumberish;
	current_energy_reserve: BigNumberish;
	last_energy_payment_block: BigNumberish;
	last_decay_processed_block: BigNumberish;
	decay_level: BigNumberish;
	claimable_since_block: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::RegulatorConfig` struct
export interface RegulatorConfig {
	slot: BigNumberish;
	epoch_blocks: BigNumberish;
	keeper_bounty_energy: BigNumberish;
	keeper_bounty_max: BigNumberish;
	bounty_funding_share_bp: BigNumberish;
	inflation_target_pct: BigNumberish;
	inflation_deadband_pct: BigNumberish;
	policy_slew_limit_bp: BigNumberish;
	min_conversion_tax_bp: BigNumberish;
	max_conversion_tax_bp: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::RegulatorPolicy` struct
export interface RegulatorPolicy {
	slot: BigNumberish;
	policy_epoch: BigNumberish;
	conversion_tax_bp: BigNumberish;
	upkeep_bp: BigNumberish;
	mint_discount_bp: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::RegulatorState` struct
export interface RegulatorState {
	slot: BigNumberish;
	has_ticked: boolean;
	last_tick_block: BigNumberish;
	last_tick_epoch: BigNumberish;
}

// Type definition for `dojo_starter::models::economics::RegulatorTreasury` struct
export interface RegulatorTreasury {
	slot: BigNumberish;
	regulator_bounty_pool: BigNumberish;
	last_bounty_epoch: BigNumberish;
	last_bounty_paid: BigNumberish;
	last_bounty_caller: string;
}

// Type definition for `dojo_starter::models::harvesting::HarvestReservation` struct
export interface HarvestReservation {
	reservation_id: BigNumberish;
	adventurer_id: BigNumberish;
	plant_key: BigNumberish;
	reserved_amount: BigNumberish;
	created_block: BigNumberish;
	expiry_block: BigNumberish;
	status: HarvestReservationStatusEnum;
}

// Type definition for `dojo_starter::models::harvesting::PlantNode` struct
export interface PlantNode {
	plant_key: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	plant_id: BigNumberish;
	species: BigNumberish;
	current_yield: BigNumberish;
	reserved_yield: BigNumberish;
	max_yield: BigNumberish;
	regrowth_rate: BigNumberish;
	health: BigNumberish;
	stress_level: BigNumberish;
	genetics_hash: BigNumberish;
	last_harvest_block: BigNumberish;
	discoverer: string;
}

// Type definition for `dojo_starter::models::inventory::BackpackItem` struct
export interface BackpackItem {
	adventurer_id: BigNumberish;
	item_id: BigNumberish;
	quantity: BigNumberish;
	quality: BigNumberish;
	weight_per_unit: BigNumberish;
}

// Type definition for `dojo_starter::models::inventory::Inventory` struct
export interface Inventory {
	adventurer_id: BigNumberish;
	current_weight: BigNumberish;
	max_weight: BigNumberish;
}

// Type definition for `dojo_starter::models::mining::MineAccessGrant` struct
export interface MineAccessGrant {
	mine_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	is_allowed: boolean;
	granted_by_adventurer_id: BigNumberish;
	grant_block: BigNumberish;
	revoked_block: BigNumberish;
}

// Type definition for `dojo_starter::models::mining::MineCollapseRecord` struct
export interface MineCollapseRecord {
	mine_key: BigNumberish;
	collapse_count: BigNumberish;
	last_collapse_block: BigNumberish;
	trigger_stress: BigNumberish;
	trigger_active_miners: BigNumberish;
}

// Type definition for `dojo_starter::models::mining::MineNode` struct
export interface MineNode {
	mine_key: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	mine_id: BigNumberish;
	ore_id: BigNumberish;
	rarity_tier: BigNumberish;
	depth_tier: BigNumberish;
	richness_bp: BigNumberish;
	remaining_reserve: BigNumberish;
	base_stress_per_block: BigNumberish;
	collapse_threshold: BigNumberish;
	mine_stress: BigNumberish;
	safe_shift_blocks: BigNumberish;
	active_miners: BigNumberish;
	last_update_block: BigNumberish;
	collapsed_until_block: BigNumberish;
	repair_energy_needed: BigNumberish;
	is_depleted: boolean;
	active_head_shift_id: BigNumberish;
	active_tail_shift_id: BigNumberish;
	biome_risk_bp: BigNumberish;
	rarity_risk_bp: BigNumberish;
	base_tick_energy: BigNumberish;
	ore_energy_weight: BigNumberish;
	conversion_energy_per_unit: BigNumberish;
}

// Type definition for `dojo_starter::models::mining::MiningShift` struct
export interface MiningShift {
	shift_id: BigNumberish;
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	status: MiningShiftStatusEnum;
	start_block: BigNumberish;
	last_settle_block: BigNumberish;
	accrued_ore_unbanked: BigNumberish;
	accrued_stabilization_work: BigNumberish;
	prev_active_shift_id: BigNumberish;
	next_active_shift_id: BigNumberish;
}

// Type definition for `dojo_starter::models::ownership::AreaOwnership` struct
export interface AreaOwnership {
	area_id: BigNumberish;
	owner_adventurer_id: BigNumberish;
	discoverer_adventurer_id: BigNumberish;
	discovery_block: BigNumberish;
	claim_block: BigNumberish;
}

// Type definition for `dojo_starter::models::sharing::ResourceAccessGrant` struct
export interface ResourceAccessGrant {
	resource_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	permissions_mask: BigNumberish;
	granted_by_adventurer_id: BigNumberish;
	grant_block: BigNumberish;
	revoke_block: BigNumberish;
	is_active: boolean;
	policy_epoch: BigNumberish;
}

// Type definition for `dojo_starter::models::sharing::ResourceDistributionNonce` struct
export interface ResourceDistributionNonce {
	resource_key: BigNumberish;
	last_nonce: BigNumberish;
}

// Type definition for `dojo_starter::models::sharing::ResourcePolicy` struct
export interface ResourcePolicy {
	resource_key: BigNumberish;
	scope: PolicyScopeEnum;
	scope_key: BigNumberish;
	resource_kind: ResourceKindEnum;
	controller_adventurer_id: BigNumberish;
	policy_epoch: BigNumberish;
	is_enabled: boolean;
	updated_block: BigNumberish;
	last_mutation_block: BigNumberish;
}

// Type definition for `dojo_starter::models::sharing::ResourceShareRule` struct
export interface ResourceShareRule {
	resource_key: BigNumberish;
	recipient_adventurer_id: BigNumberish;
	rule_kind: ShareRuleKindEnum;
	share_bp: BigNumberish;
	is_active: boolean;
	policy_epoch: BigNumberish;
	updated_block: BigNumberish;
}

// Type definition for `dojo_starter::models::sharing::ResourceShareRuleTally` struct
export interface ResourceShareRuleTally {
	resource_key: BigNumberish;
	rule_kind: ShareRuleKindEnum;
	total_bp: BigNumberish;
	active_recipient_count: BigNumberish;
	policy_epoch: BigNumberish;
	recipient_0: BigNumberish;
	recipient_1: BigNumberish;
	recipient_2: BigNumberish;
	recipient_3: BigNumberish;
	recipient_4: BigNumberish;
	recipient_5: BigNumberish;
	recipient_6: BigNumberish;
	recipient_7: BigNumberish;
	updated_block: BigNumberish;
}

// Type definition for `dojo_starter::models::world::Hex` struct
export interface Hex {
	coordinate: BigNumberish;
	biome: BiomeEnum;
	is_discovered: boolean;
	discovery_block: BigNumberish;
	discoverer: string;
	area_count: BigNumberish;
}

// Type definition for `dojo_starter::models::world::HexArea` struct
export interface HexArea {
	area_id: BigNumberish;
	hex_coordinate: BigNumberish;
	area_index: BigNumberish;
	area_type: AreaTypeEnum;
	is_discovered: boolean;
	discoverer: string;
	resource_quality: BigNumberish;
	size_category: SizeCategoryEnum;
	plant_slot_count: BigNumberish;
}

// Type definition for `dojo_starter::models::world::WorldGenConfig` struct
export interface WorldGenConfig {
	generation_version: BigNumberish;
	global_seed: BigNumberish;
	biome_scale_bp: BigNumberish;
	area_scale_bp: BigNumberish;
	plant_scale_bp: BigNumberish;
	biome_octaves: BigNumberish;
	area_octaves: BigNumberish;
	plant_octaves: BigNumberish;
}

// Type definition for `dojo_starter::events::adventurer_events::AdventurerCreated` struct
export interface AdventurerCreated {
	adventurer_id: BigNumberish;
	owner: string;
}

// Type definition for `dojo_starter::events::adventurer_events::AdventurerDied` struct
export interface AdventurerDied {
	adventurer_id: BigNumberish;
	owner: string;
	cause: BigNumberish;
}

// Type definition for `dojo_starter::events::adventurer_events::AdventurerMoved` struct
export interface AdventurerMoved {
	adventurer_id: BigNumberish;
	from: BigNumberish;
	to: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionCompleted` struct
export interface ConstructionCompleted {
	project_id: BigNumberish;
	adventurer_id: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	building_type: BigNumberish;
	resulting_tier: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionPlantProcessed` struct
export interface ConstructionPlantProcessed {
	adventurer_id: BigNumberish;
	source_item_id: BigNumberish;
	target_material: BigNumberish;
	input_qty: BigNumberish;
	output_qty: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionRejected` struct
export interface ConstructionRejected {
	adventurer_id: BigNumberish;
	area_id: BigNumberish;
	action: BigNumberish;
	reason: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionRepaired` struct
export interface ConstructionRepaired {
	area_id: BigNumberish;
	adventurer_id: BigNumberish;
	amount: BigNumberish;
	condition_bp: BigNumberish;
	is_active: boolean;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionStarted` struct
export interface ConstructionStarted {
	project_id: BigNumberish;
	adventurer_id: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	building_type: BigNumberish;
	target_tier: BigNumberish;
	completion_block: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionUpgradeQueued` struct
export interface ConstructionUpgradeQueued {
	area_id: BigNumberish;
	project_id: BigNumberish;
	adventurer_id: BigNumberish;
	target_tier: BigNumberish;
}

// Type definition for `dojo_starter::events::construction_events::ConstructionUpkeepPaid` struct
export interface ConstructionUpkeepPaid {
	area_id: BigNumberish;
	adventurer_id: BigNumberish;
	amount: BigNumberish;
	upkeep_reserve: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::BountyPaid` struct
export interface BountyPaid {
	epoch: BigNumberish;
	caller: string;
	amount: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::ClaimExpired` struct
export interface ClaimExpired {
	hex: BigNumberish;
	claim_id: BigNumberish;
	claimant: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::ClaimInitiated` struct
export interface ClaimInitiated {
	hex: BigNumberish;
	claimant: BigNumberish;
	claim_id: BigNumberish;
	energy_locked: BigNumberish;
	expiry_block: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::ClaimRefunded` struct
export interface ClaimRefunded {
	hex: BigNumberish;
	claim_id: BigNumberish;
	claimant: BigNumberish;
	amount: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::HexBecameClaimable` struct
export interface HexBecameClaimable {
	hex: BigNumberish;
	min_energy_to_claim: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::HexDefended` struct
export interface HexDefended {
	hex: BigNumberish;
	owner: BigNumberish;
	energy: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::HexEnergyPaid` struct
export interface HexEnergyPaid {
	hex: BigNumberish;
	payer: BigNumberish;
	amount: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::ItemsConverted` struct
export interface ItemsConverted {
	adventurer_id: BigNumberish;
	item_id: BigNumberish;
	quantity: BigNumberish;
	energy_gained: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::RegulatorPolicyUpdated` struct
export interface RegulatorPolicyUpdated {
	epoch: BigNumberish;
	conversion_tax_bp: BigNumberish;
	upkeep_bp: BigNumberish;
	mint_discount_bp: BigNumberish;
}

// Type definition for `dojo_starter::events::economic_events::RegulatorTicked` struct
export interface RegulatorTicked {
	epoch: BigNumberish;
	caller: string;
	bounty_paid: BigNumberish;
	status: BigNumberish;
}

// Type definition for `dojo_starter::events::harvesting_events::HarvestingCancelled` struct
export interface HarvestingCancelled {
	adventurer_id: BigNumberish;
	partial_yield: BigNumberish;
}

// Type definition for `dojo_starter::events::harvesting_events::HarvestingCompleted` struct
export interface HarvestingCompleted {
	adventurer_id: BigNumberish;
	hex: BigNumberish;
	area_id: BigNumberish;
	plant_id: BigNumberish;
	actual_yield: BigNumberish;
}

// Type definition for `dojo_starter::events::harvesting_events::HarvestingRejected` struct
export interface HarvestingRejected {
	adventurer_id: BigNumberish;
	hex: BigNumberish;
	area_id: BigNumberish;
	plant_id: BigNumberish;
	phase: BigNumberish;
	reason: BigNumberish;
}

// Type definition for `dojo_starter::events::harvesting_events::HarvestingStarted` struct
export interface HarvestingStarted {
	adventurer_id: BigNumberish;
	hex: BigNumberish;
	area_id: BigNumberish;
	plant_id: BigNumberish;
	amount: BigNumberish;
	eta: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineAccessGranted` struct
export interface MineAccessGranted {
	mine_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	granted_by_adventurer_id: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineAccessRevoked` struct
export interface MineAccessRevoked {
	mine_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	revoked_by_adventurer_id: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineCollapsed` struct
export interface MineCollapsed {
	mine_key: BigNumberish;
	killed_miners: BigNumberish;
	collapse_count: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineInitialized` struct
export interface MineInitialized {
	mine_key: BigNumberish;
	hex_coordinate: BigNumberish;
	area_id: BigNumberish;
	mine_id: BigNumberish;
	ore_id: BigNumberish;
	rarity_tier: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineRepaired` struct
export interface MineRepaired {
	mine_key: BigNumberish;
	adventurer_id: BigNumberish;
	energy_contributed: BigNumberish;
	repair_energy_remaining: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MineStabilized` struct
export interface MineStabilized {
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	stress_reduced: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MiningContinued` struct
export interface MiningContinued {
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	mined_ore: BigNumberish;
	energy_spent: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MiningExited` struct
export interface MiningExited {
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	banked_ore: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MiningRejected` struct
export interface MiningRejected {
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	action: BigNumberish;
	reason: BigNumberish;
}

// Type definition for `dojo_starter::events::mining_events::MiningStarted` struct
export interface MiningStarted {
	adventurer_id: BigNumberish;
	mine_key: BigNumberish;
	start_block: BigNumberish;
}

// Type definition for `dojo_starter::events::ownership_events::AreaOwnershipAssigned` struct
export interface AreaOwnershipAssigned {
	area_id: BigNumberish;
	owner_adventurer_id: BigNumberish;
	discoverer_adventurer_id: BigNumberish;
	claim_block: BigNumberish;
}

// Type definition for `dojo_starter::events::ownership_events::OwnershipTransferred` struct
export interface OwnershipTransferred {
	area_id: BigNumberish;
	from_adventurer_id: BigNumberish;
	to_adventurer_id: BigNumberish;
	claim_block: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourceAccessGranted` struct
export interface ResourceAccessGranted {
	resource_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	granted_by_adventurer_id: BigNumberish;
	permissions_mask: BigNumberish;
	policy_epoch: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourceAccessRevoked` struct
export interface ResourceAccessRevoked {
	resource_key: BigNumberish;
	grantee_adventurer_id: BigNumberish;
	revoked_by_adventurer_id: BigNumberish;
	policy_epoch: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourcePermissionRejected` struct
export interface ResourcePermissionRejected {
	adventurer_id: BigNumberish;
	resource_key: BigNumberish;
	action: BigNumberish;
	reason: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourcePolicyUpserted` struct
export interface ResourcePolicyUpserted {
	resource_key: BigNumberish;
	scope: PolicyScopeEnum;
	scope_key: BigNumberish;
	resource_kind: ResourceKindEnum;
	controller_adventurer_id: BigNumberish;
	policy_epoch: BigNumberish;
	is_enabled: boolean;
	updated_block: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourceShareRuleCleared` struct
export interface ResourceShareRuleCleared {
	resource_key: BigNumberish;
	recipient_adventurer_id: BigNumberish;
	rule_kind: ShareRuleKindEnum;
	policy_epoch: BigNumberish;
}

// Type definition for `dojo_starter::events::sharing_events::ResourceShareRuleSet` struct
export interface ResourceShareRuleSet {
	resource_key: BigNumberish;
	recipient_adventurer_id: BigNumberish;
	rule_kind: ShareRuleKindEnum;
	share_bp: BigNumberish;
	policy_epoch: BigNumberish;
}

// Type definition for `dojo_starter::events::world_events::AreaDiscovered` struct
export interface AreaDiscovered {
	area_id: BigNumberish;
	hex: BigNumberish;
	area_type: AreaTypeEnum;
	discoverer: string;
}

// Type definition for `dojo_starter::events::world_events::HexDiscovered` struct
export interface HexDiscovered {
	hex: BigNumberish;
	biome: BiomeEnum;
	discoverer: string;
}

// Type definition for `dojo_starter::events::world_events::WorldActionRejected` struct
export interface WorldActionRejected {
	adventurer_id: BigNumberish;
	action: BigNumberish;
	target: BigNumberish;
	reason: BigNumberish;
}

// Type definition for `dojo_starter::events::world_events::WorldGenConfigInitialized` struct
export interface WorldGenConfigInitialized {
	generation_version: BigNumberish;
	global_seed: BigNumberish;
	biome_scale_bp: BigNumberish;
	area_scale_bp: BigNumberish;
	plant_scale_bp: BigNumberish;
	biome_octaves: BigNumberish;
	area_octaves: BigNumberish;
	plant_octaves: BigNumberish;
}

// Type definition for `dojo_starter::systems::autoregulator_manager::TickOutcome` struct
export interface TickOutcome {
	status: TickStatusEnum;
	epoch: BigNumberish;
	bounty_paid: BigNumberish;
	policy_changed: boolean;
}

// Type definition for `dojo_starter::models::construction::ConstructionProjectStatus` enum
export const constructionProjectStatus = [
	'Inactive',
	'Active',
	'Completed',
	'Canceled',
] as const;
export type ConstructionProjectStatus = { [key in typeof constructionProjectStatus[number]]: string };
export type ConstructionProjectStatusEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::economics::ClaimEscrowStatus` enum
export const claimEscrowStatus = [
	'Inactive',
	'Active',
	'Expired',
	'Resolved',
] as const;
export type ClaimEscrowStatus = { [key in typeof claimEscrowStatus[number]]: string };
export type ClaimEscrowStatusEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::harvesting::HarvestReservationStatus` enum
export const harvestReservationStatus = [
	'Inactive',
	'Active',
	'Completed',
	'Canceled',
] as const;
export type HarvestReservationStatus = { [key in typeof harvestReservationStatus[number]]: string };
export type HarvestReservationStatusEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::mining::MiningShiftStatus` enum
export const miningShiftStatus = [
	'Inactive',
	'Active',
	'Exited',
	'Collapsed',
	'Completed',
] as const;
export type MiningShiftStatus = { [key in typeof miningShiftStatus[number]]: string };
export type MiningShiftStatusEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::sharing::PolicyScope` enum
export const policyScope = [
	'None',
	'Global',
	'Hex',
	'Area',
] as const;
export type PolicyScope = { [key in typeof policyScope[number]]: string };
export type PolicyScopeEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::sharing::ResourceKind` enum
export const resourceKind = [
	'Unknown',
	'Mine',
	'PlantArea',
	'ConstructionArea',
] as const;
export type ResourceKind = { [key in typeof resourceKind[number]]: string };
export type ResourceKindEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::sharing::ShareRuleKind` enum
export const shareRuleKind = [
	'OutputItem',
	'OutputEnergy',
	'FeeOnly',
] as const;
export type ShareRuleKind = { [key in typeof shareRuleKind[number]]: string };
export type ShareRuleKindEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::world::AreaType` enum
export const areaType = [
	'Wilderness',
	'Control',
	'PlantField',
	'MineField',
] as const;
export type AreaType = { [key in typeof areaType[number]]: string };
export type AreaTypeEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::world::Biome` enum
export const biome = [
	'Unknown',
	'Plains',
	'Forest',
	'Mountain',
	'Desert',
	'Swamp',
	'Tundra',
	'Taiga',
	'Jungle',
	'Savanna',
	'Grassland',
	'Canyon',
	'Badlands',
	'Volcanic',
	'Glacier',
	'Wetlands',
	'Steppe',
	'Oasis',
	'Mire',
	'Highlands',
	'Coast',
] as const;
export type Biome = { [key in typeof biome[number]]: string };
export type BiomeEnum = CairoCustomEnum;

// Type definition for `dojo_starter::models::world::SizeCategory` enum
export const sizeCategory = [
	'Small',
	'Medium',
	'Large',
] as const;
export type SizeCategory = { [key in typeof sizeCategory[number]]: string };
export type SizeCategoryEnum = CairoCustomEnum;

// Type definition for `dojo_starter::systems::autoregulator_manager::TickStatus` enum
export const tickStatus = [
	'NoOpEarly',
	'NoOpAlreadyTicked',
	'Applied',
] as const;
export type TickStatus = { [key in typeof tickStatus[number]]: string };
export type TickStatusEnum = CairoCustomEnum;

export interface SchemaType extends ISchemaType {
	dojo_starter: {
		Adventurer: Adventurer,
		ConstructionBuildingNode: ConstructionBuildingNode,
		ConstructionMaterialEscrow: ConstructionMaterialEscrow,
		ConstructionProject: ConstructionProject,
		DeathRecord: DeathRecord,
		AdventurerEconomics: AdventurerEconomics,
		ClaimEscrow: ClaimEscrow,
		ConversionRate: ConversionRate,
		EconomyAccumulator: EconomyAccumulator,
		EconomyEpochSnapshot: EconomyEpochSnapshot,
		HexDecayState: HexDecayState,
		RegulatorConfig: RegulatorConfig,
		RegulatorPolicy: RegulatorPolicy,
		RegulatorState: RegulatorState,
		RegulatorTreasury: RegulatorTreasury,
		HarvestReservation: HarvestReservation,
		PlantNode: PlantNode,
		BackpackItem: BackpackItem,
		Inventory: Inventory,
		MineAccessGrant: MineAccessGrant,
		MineCollapseRecord: MineCollapseRecord,
		MineNode: MineNode,
		MiningShift: MiningShift,
		AreaOwnership: AreaOwnership,
		ResourceAccessGrant: ResourceAccessGrant,
		ResourceDistributionNonce: ResourceDistributionNonce,
		ResourcePolicy: ResourcePolicy,
		ResourceShareRule: ResourceShareRule,
		ResourceShareRuleTally: ResourceShareRuleTally,
		Hex: Hex,
		HexArea: HexArea,
		WorldGenConfig: WorldGenConfig,
		AdventurerCreated: AdventurerCreated,
		AdventurerDied: AdventurerDied,
		AdventurerMoved: AdventurerMoved,
		ConstructionCompleted: ConstructionCompleted,
		ConstructionPlantProcessed: ConstructionPlantProcessed,
		ConstructionRejected: ConstructionRejected,
		ConstructionRepaired: ConstructionRepaired,
		ConstructionStarted: ConstructionStarted,
		ConstructionUpgradeQueued: ConstructionUpgradeQueued,
		ConstructionUpkeepPaid: ConstructionUpkeepPaid,
		BountyPaid: BountyPaid,
		ClaimExpired: ClaimExpired,
		ClaimInitiated: ClaimInitiated,
		ClaimRefunded: ClaimRefunded,
		HexBecameClaimable: HexBecameClaimable,
		HexDefended: HexDefended,
		HexEnergyPaid: HexEnergyPaid,
		ItemsConverted: ItemsConverted,
		RegulatorPolicyUpdated: RegulatorPolicyUpdated,
		RegulatorTicked: RegulatorTicked,
		HarvestingCancelled: HarvestingCancelled,
		HarvestingCompleted: HarvestingCompleted,
		HarvestingRejected: HarvestingRejected,
		HarvestingStarted: HarvestingStarted,
		MineAccessGranted: MineAccessGranted,
		MineAccessRevoked: MineAccessRevoked,
		MineCollapsed: MineCollapsed,
		MineInitialized: MineInitialized,
		MineRepaired: MineRepaired,
		MineStabilized: MineStabilized,
		MiningContinued: MiningContinued,
		MiningExited: MiningExited,
		MiningRejected: MiningRejected,
		MiningStarted: MiningStarted,
		AreaOwnershipAssigned: AreaOwnershipAssigned,
		OwnershipTransferred: OwnershipTransferred,
		ResourceAccessGranted: ResourceAccessGranted,
		ResourceAccessRevoked: ResourceAccessRevoked,
		ResourcePermissionRejected: ResourcePermissionRejected,
		ResourcePolicyUpserted: ResourcePolicyUpserted,
		ResourceShareRuleCleared: ResourceShareRuleCleared,
		ResourceShareRuleSet: ResourceShareRuleSet,
		AreaDiscovered: AreaDiscovered,
		HexDiscovered: HexDiscovered,
		WorldActionRejected: WorldActionRejected,
		WorldGenConfigInitialized: WorldGenConfigInitialized,
		TickOutcome: TickOutcome,
	},
}
export const schema: SchemaType = {
	dojo_starter: {
		Adventurer: {
			adventurer_id: 0,
			owner: "",
			name: 0,
			energy: 0,
			max_energy: 0,
			current_hex: 0,
			activity_locked_until: 0,
			is_alive: false,
		},
		ConstructionBuildingNode: {
			area_id: 0,
			hex_coordinate: 0,
			owner_adventurer_id: 0,
			building_type: 0,
			tier: 0,
			condition_bp: 0,
			upkeep_reserve: 0,
			last_upkeep_block: 0,
			is_active: false,
		},
		ConstructionMaterialEscrow: {
			project_id: 0,
			item_id: 0,
			quantity: 0,
		},
		ConstructionProject: {
			project_id: 0,
			adventurer_id: 0,
			hex_coordinate: 0,
			area_id: 0,
			building_type: 0,
			target_tier: 0,
			start_block: 0,
			completion_block: 0,
			energy_staked: 0,
		status: new CairoCustomEnum({ 
					Inactive: "",
				Active: undefined,
				Completed: undefined,
				Canceled: undefined, }),
		},
		DeathRecord: {
			adventurer_id: 0,
			owner: "",
			death_block: 0,
			death_cause: 0,
			inventory_lost_hash: 0,
		},
		AdventurerEconomics: {
			adventurer_id: 0,
			energy_balance: 0,
			total_energy_spent: 0,
			total_energy_earned: 0,
			last_regen_block: 0,
		},
		ClaimEscrow: {
			claim_id: 0,
			hex_coordinate: 0,
			claimant_adventurer_id: 0,
			energy_locked: 0,
			created_block: 0,
			expiry_block: 0,
		status: new CairoCustomEnum({ 
					Inactive: "",
				Active: undefined,
				Expired: undefined,
				Resolved: undefined, }),
		},
		ConversionRate: {
			item_type: 0,
			current_rate: 0,
			base_rate: 0,
			last_update_block: 0,
			units_converted_in_window: 0,
		},
		EconomyAccumulator: {
			epoch: 0,
			total_sources: 0,
			total_sinks: 0,
			new_hexes: 0,
			deaths: 0,
			mints: 0,
		},
		EconomyEpochSnapshot: {
			epoch: 0,
			total_sources: 0,
			total_sinks: 0,
			net_energy: 0,
			new_hexes: 0,
			deaths: 0,
			mints: 0,
			finalized_at_block: 0,
			is_finalized: false,
		},
		HexDecayState: {
			hex_coordinate: 0,
			owner_adventurer_id: 0,
			current_energy_reserve: 0,
			last_energy_payment_block: 0,
			last_decay_processed_block: 0,
			decay_level: 0,
			claimable_since_block: 0,
		},
		RegulatorConfig: {
			slot: 0,
			epoch_blocks: 0,
			keeper_bounty_energy: 0,
			keeper_bounty_max: 0,
			bounty_funding_share_bp: 0,
			inflation_target_pct: 0,
			inflation_deadband_pct: 0,
			policy_slew_limit_bp: 0,
			min_conversion_tax_bp: 0,
			max_conversion_tax_bp: 0,
		},
		RegulatorPolicy: {
			slot: 0,
			policy_epoch: 0,
			conversion_tax_bp: 0,
			upkeep_bp: 0,
			mint_discount_bp: 0,
		},
		RegulatorState: {
			slot: 0,
			has_ticked: false,
			last_tick_block: 0,
			last_tick_epoch: 0,
		},
		RegulatorTreasury: {
			slot: 0,
			regulator_bounty_pool: 0,
			last_bounty_epoch: 0,
			last_bounty_paid: 0,
			last_bounty_caller: "",
		},
		HarvestReservation: {
			reservation_id: 0,
			adventurer_id: 0,
			plant_key: 0,
			reserved_amount: 0,
			created_block: 0,
			expiry_block: 0,
		status: new CairoCustomEnum({ 
					Inactive: "",
				Active: undefined,
				Completed: undefined,
				Canceled: undefined, }),
		},
		PlantNode: {
			plant_key: 0,
			hex_coordinate: 0,
			area_id: 0,
			plant_id: 0,
			species: 0,
			current_yield: 0,
			reserved_yield: 0,
			max_yield: 0,
			regrowth_rate: 0,
			health: 0,
			stress_level: 0,
			genetics_hash: 0,
			last_harvest_block: 0,
			discoverer: "",
		},
		BackpackItem: {
			adventurer_id: 0,
			item_id: 0,
			quantity: 0,
			quality: 0,
			weight_per_unit: 0,
		},
		Inventory: {
			adventurer_id: 0,
			current_weight: 0,
			max_weight: 0,
		},
		MineAccessGrant: {
			mine_key: 0,
			grantee_adventurer_id: 0,
			is_allowed: false,
			granted_by_adventurer_id: 0,
			grant_block: 0,
			revoked_block: 0,
		},
		MineCollapseRecord: {
			mine_key: 0,
			collapse_count: 0,
			last_collapse_block: 0,
			trigger_stress: 0,
			trigger_active_miners: 0,
		},
		MineNode: {
			mine_key: 0,
			hex_coordinate: 0,
			area_id: 0,
			mine_id: 0,
			ore_id: 0,
			rarity_tier: 0,
			depth_tier: 0,
			richness_bp: 0,
			remaining_reserve: 0,
			base_stress_per_block: 0,
			collapse_threshold: 0,
			mine_stress: 0,
			safe_shift_blocks: 0,
			active_miners: 0,
			last_update_block: 0,
			collapsed_until_block: 0,
			repair_energy_needed: 0,
			is_depleted: false,
			active_head_shift_id: 0,
			active_tail_shift_id: 0,
			biome_risk_bp: 0,
			rarity_risk_bp: 0,
			base_tick_energy: 0,
			ore_energy_weight: 0,
			conversion_energy_per_unit: 0,
		},
		MiningShift: {
			shift_id: 0,
			adventurer_id: 0,
			mine_key: 0,
		status: new CairoCustomEnum({ 
					Inactive: "",
				Active: undefined,
				Exited: undefined,
				Collapsed: undefined,
				Completed: undefined, }),
			start_block: 0,
			last_settle_block: 0,
			accrued_ore_unbanked: 0,
			accrued_stabilization_work: 0,
			prev_active_shift_id: 0,
			next_active_shift_id: 0,
		},
		AreaOwnership: {
			area_id: 0,
			owner_adventurer_id: 0,
			discoverer_adventurer_id: 0,
			discovery_block: 0,
			claim_block: 0,
		},
		ResourceAccessGrant: {
			resource_key: 0,
			grantee_adventurer_id: 0,
			permissions_mask: 0,
			granted_by_adventurer_id: 0,
			grant_block: 0,
			revoke_block: 0,
			is_active: false,
			policy_epoch: 0,
		},
		ResourceDistributionNonce: {
			resource_key: 0,
			last_nonce: 0,
		},
		ResourcePolicy: {
			resource_key: 0,
		scope: new CairoCustomEnum({ 
					None: "",
				Global: undefined,
				Hex: undefined,
				Area: undefined, }),
			scope_key: 0,
		resource_kind: new CairoCustomEnum({ 
					Unknown: "",
				Mine: undefined,
				PlantArea: undefined,
				ConstructionArea: undefined, }),
			controller_adventurer_id: 0,
			policy_epoch: 0,
			is_enabled: false,
			updated_block: 0,
			last_mutation_block: 0,
		},
		ResourceShareRule: {
			resource_key: 0,
			recipient_adventurer_id: 0,
		rule_kind: new CairoCustomEnum({ 
					OutputItem: "",
				OutputEnergy: undefined,
				FeeOnly: undefined, }),
			share_bp: 0,
			is_active: false,
			policy_epoch: 0,
			updated_block: 0,
		},
		ResourceShareRuleTally: {
			resource_key: 0,
		rule_kind: new CairoCustomEnum({ 
					OutputItem: "",
				OutputEnergy: undefined,
				FeeOnly: undefined, }),
			total_bp: 0,
			active_recipient_count: 0,
			policy_epoch: 0,
			recipient_0: 0,
			recipient_1: 0,
			recipient_2: 0,
			recipient_3: 0,
			recipient_4: 0,
			recipient_5: 0,
			recipient_6: 0,
			recipient_7: 0,
			updated_block: 0,
		},
		Hex: {
			coordinate: 0,
		biome: new CairoCustomEnum({ 
					Unknown: "",
				Plains: undefined,
				Forest: undefined,
				Mountain: undefined,
				Desert: undefined,
				Swamp: undefined,
				Tundra: undefined,
				Taiga: undefined,
				Jungle: undefined,
				Savanna: undefined,
				Grassland: undefined,
				Canyon: undefined,
				Badlands: undefined,
				Volcanic: undefined,
				Glacier: undefined,
				Wetlands: undefined,
				Steppe: undefined,
				Oasis: undefined,
				Mire: undefined,
				Highlands: undefined,
				Coast: undefined, }),
			is_discovered: false,
			discovery_block: 0,
			discoverer: "",
			area_count: 0,
		},
		HexArea: {
			area_id: 0,
			hex_coordinate: 0,
			area_index: 0,
		area_type: new CairoCustomEnum({ 
					Wilderness: "",
				Control: undefined,
				PlantField: undefined,
				MineField: undefined, }),
			is_discovered: false,
			discoverer: "",
			resource_quality: 0,
		size_category: new CairoCustomEnum({ 
					Small: "",
				Medium: undefined,
				Large: undefined, }),
			plant_slot_count: 0,
		},
		WorldGenConfig: {
			generation_version: 0,
			global_seed: 0,
			biome_scale_bp: 0,
			area_scale_bp: 0,
			plant_scale_bp: 0,
			biome_octaves: 0,
			area_octaves: 0,
			plant_octaves: 0,
		},
		AdventurerCreated: {
			adventurer_id: 0,
			owner: "",
		},
		AdventurerDied: {
			adventurer_id: 0,
			owner: "",
			cause: 0,
		},
		AdventurerMoved: {
			adventurer_id: 0,
			from: 0,
			to: 0,
		},
		ConstructionCompleted: {
			project_id: 0,
			adventurer_id: 0,
			hex_coordinate: 0,
			area_id: 0,
			building_type: 0,
			resulting_tier: 0,
		},
		ConstructionPlantProcessed: {
			adventurer_id: 0,
			source_item_id: 0,
			target_material: 0,
			input_qty: 0,
			output_qty: 0,
		},
		ConstructionRejected: {
			adventurer_id: 0,
			area_id: 0,
			action: 0,
			reason: 0,
		},
		ConstructionRepaired: {
			area_id: 0,
			adventurer_id: 0,
			amount: 0,
			condition_bp: 0,
			is_active: false,
		},
		ConstructionStarted: {
			project_id: 0,
			adventurer_id: 0,
			hex_coordinate: 0,
			area_id: 0,
			building_type: 0,
			target_tier: 0,
			completion_block: 0,
		},
		ConstructionUpgradeQueued: {
			area_id: 0,
			project_id: 0,
			adventurer_id: 0,
			target_tier: 0,
		},
		ConstructionUpkeepPaid: {
			area_id: 0,
			adventurer_id: 0,
			amount: 0,
			upkeep_reserve: 0,
		},
		BountyPaid: {
			epoch: 0,
			caller: "",
			amount: 0,
		},
		ClaimExpired: {
			hex: 0,
			claim_id: 0,
			claimant: 0,
		},
		ClaimInitiated: {
			hex: 0,
			claimant: 0,
			claim_id: 0,
			energy_locked: 0,
			expiry_block: 0,
		},
		ClaimRefunded: {
			hex: 0,
			claim_id: 0,
			claimant: 0,
			amount: 0,
		},
		HexBecameClaimable: {
			hex: 0,
			min_energy_to_claim: 0,
		},
		HexDefended: {
			hex: 0,
			owner: 0,
			energy: 0,
		},
		HexEnergyPaid: {
			hex: 0,
			payer: 0,
			amount: 0,
		},
		ItemsConverted: {
			adventurer_id: 0,
			item_id: 0,
			quantity: 0,
			energy_gained: 0,
		},
		RegulatorPolicyUpdated: {
			epoch: 0,
			conversion_tax_bp: 0,
			upkeep_bp: 0,
			mint_discount_bp: 0,
		},
		RegulatorTicked: {
			epoch: 0,
			caller: "",
			bounty_paid: 0,
			status: 0,
		},
		HarvestingCancelled: {
			adventurer_id: 0,
			partial_yield: 0,
		},
		HarvestingCompleted: {
			adventurer_id: 0,
			hex: 0,
			area_id: 0,
			plant_id: 0,
			actual_yield: 0,
		},
		HarvestingRejected: {
			adventurer_id: 0,
			hex: 0,
			area_id: 0,
			plant_id: 0,
			phase: 0,
			reason: 0,
		},
		HarvestingStarted: {
			adventurer_id: 0,
			hex: 0,
			area_id: 0,
			plant_id: 0,
			amount: 0,
			eta: 0,
		},
		MineAccessGranted: {
			mine_key: 0,
			grantee_adventurer_id: 0,
			granted_by_adventurer_id: 0,
		},
		MineAccessRevoked: {
			mine_key: 0,
			grantee_adventurer_id: 0,
			revoked_by_adventurer_id: 0,
		},
		MineCollapsed: {
			mine_key: 0,
			killed_miners: 0,
			collapse_count: 0,
		},
		MineInitialized: {
			mine_key: 0,
			hex_coordinate: 0,
			area_id: 0,
			mine_id: 0,
			ore_id: 0,
			rarity_tier: 0,
		},
		MineRepaired: {
			mine_key: 0,
			adventurer_id: 0,
			energy_contributed: 0,
			repair_energy_remaining: 0,
		},
		MineStabilized: {
			adventurer_id: 0,
			mine_key: 0,
			stress_reduced: 0,
		},
		MiningContinued: {
			adventurer_id: 0,
			mine_key: 0,
			mined_ore: 0,
			energy_spent: 0,
		},
		MiningExited: {
			adventurer_id: 0,
			mine_key: 0,
			banked_ore: 0,
		},
		MiningRejected: {
			adventurer_id: 0,
			mine_key: 0,
			action: 0,
			reason: 0,
		},
		MiningStarted: {
			adventurer_id: 0,
			mine_key: 0,
			start_block: 0,
		},
		AreaOwnershipAssigned: {
			area_id: 0,
			owner_adventurer_id: 0,
			discoverer_adventurer_id: 0,
			claim_block: 0,
		},
		OwnershipTransferred: {
			area_id: 0,
			from_adventurer_id: 0,
			to_adventurer_id: 0,
			claim_block: 0,
		},
		ResourceAccessGranted: {
			resource_key: 0,
			grantee_adventurer_id: 0,
			granted_by_adventurer_id: 0,
			permissions_mask: 0,
			policy_epoch: 0,
		},
		ResourceAccessRevoked: {
			resource_key: 0,
			grantee_adventurer_id: 0,
			revoked_by_adventurer_id: 0,
			policy_epoch: 0,
		},
		ResourcePermissionRejected: {
			adventurer_id: 0,
			resource_key: 0,
			action: 0,
			reason: 0,
		},
		ResourcePolicyUpserted: {
			resource_key: 0,
		scope: new CairoCustomEnum({ 
					None: "",
				Global: undefined,
				Hex: undefined,
				Area: undefined, }),
			scope_key: 0,
		resource_kind: new CairoCustomEnum({ 
					Unknown: "",
				Mine: undefined,
				PlantArea: undefined,
				ConstructionArea: undefined, }),
			controller_adventurer_id: 0,
			policy_epoch: 0,
			is_enabled: false,
			updated_block: 0,
		},
		ResourceShareRuleCleared: {
			resource_key: 0,
			recipient_adventurer_id: 0,
		rule_kind: new CairoCustomEnum({ 
					OutputItem: "",
				OutputEnergy: undefined,
				FeeOnly: undefined, }),
			policy_epoch: 0,
		},
		ResourceShareRuleSet: {
			resource_key: 0,
			recipient_adventurer_id: 0,
		rule_kind: new CairoCustomEnum({ 
					OutputItem: "",
				OutputEnergy: undefined,
				FeeOnly: undefined, }),
			share_bp: 0,
			policy_epoch: 0,
		},
		AreaDiscovered: {
			area_id: 0,
			hex: 0,
		area_type: new CairoCustomEnum({ 
					Wilderness: "",
				Control: undefined,
				PlantField: undefined,
				MineField: undefined, }),
			discoverer: "",
		},
		HexDiscovered: {
			hex: 0,
		biome: new CairoCustomEnum({ 
					Unknown: "",
				Plains: undefined,
				Forest: undefined,
				Mountain: undefined,
				Desert: undefined,
				Swamp: undefined,
				Tundra: undefined,
				Taiga: undefined,
				Jungle: undefined,
				Savanna: undefined,
				Grassland: undefined,
				Canyon: undefined,
				Badlands: undefined,
				Volcanic: undefined,
				Glacier: undefined,
				Wetlands: undefined,
				Steppe: undefined,
				Oasis: undefined,
				Mire: undefined,
				Highlands: undefined,
				Coast: undefined, }),
			discoverer: "",
		},
		WorldActionRejected: {
			adventurer_id: 0,
			action: 0,
			target: 0,
			reason: 0,
		},
		WorldGenConfigInitialized: {
			generation_version: 0,
			global_seed: 0,
			biome_scale_bp: 0,
			area_scale_bp: 0,
			plant_scale_bp: 0,
			biome_octaves: 0,
			area_octaves: 0,
			plant_octaves: 0,
		},
		TickOutcome: {
		status: new CairoCustomEnum({ 
					NoOpEarly: "",
				NoOpAlreadyTicked: undefined,
				Applied: undefined, }),
			epoch: 0,
			bounty_paid: 0,
			policy_changed: false,
		},
	},
};
export enum ModelsMapping {
	Adventurer = 'dojo_starter-Adventurer',
	ConstructionBuildingNode = 'dojo_starter-ConstructionBuildingNode',
	ConstructionMaterialEscrow = 'dojo_starter-ConstructionMaterialEscrow',
	ConstructionProject = 'dojo_starter-ConstructionProject',
	ConstructionProjectStatus = 'dojo_starter-ConstructionProjectStatus',
	DeathRecord = 'dojo_starter-DeathRecord',
	AdventurerEconomics = 'dojo_starter-AdventurerEconomics',
	ClaimEscrow = 'dojo_starter-ClaimEscrow',
	ClaimEscrowStatus = 'dojo_starter-ClaimEscrowStatus',
	ConversionRate = 'dojo_starter-ConversionRate',
	EconomyAccumulator = 'dojo_starter-EconomyAccumulator',
	EconomyEpochSnapshot = 'dojo_starter-EconomyEpochSnapshot',
	HexDecayState = 'dojo_starter-HexDecayState',
	RegulatorConfig = 'dojo_starter-RegulatorConfig',
	RegulatorPolicy = 'dojo_starter-RegulatorPolicy',
	RegulatorState = 'dojo_starter-RegulatorState',
	RegulatorTreasury = 'dojo_starter-RegulatorTreasury',
	HarvestReservation = 'dojo_starter-HarvestReservation',
	HarvestReservationStatus = 'dojo_starter-HarvestReservationStatus',
	PlantNode = 'dojo_starter-PlantNode',
	BackpackItem = 'dojo_starter-BackpackItem',
	Inventory = 'dojo_starter-Inventory',
	MineAccessGrant = 'dojo_starter-MineAccessGrant',
	MineCollapseRecord = 'dojo_starter-MineCollapseRecord',
	MineNode = 'dojo_starter-MineNode',
	MiningShift = 'dojo_starter-MiningShift',
	MiningShiftStatus = 'dojo_starter-MiningShiftStatus',
	AreaOwnership = 'dojo_starter-AreaOwnership',
	PolicyScope = 'dojo_starter-PolicyScope',
	ResourceAccessGrant = 'dojo_starter-ResourceAccessGrant',
	ResourceDistributionNonce = 'dojo_starter-ResourceDistributionNonce',
	ResourceKind = 'dojo_starter-ResourceKind',
	ResourcePolicy = 'dojo_starter-ResourcePolicy',
	ResourceShareRule = 'dojo_starter-ResourceShareRule',
	ResourceShareRuleTally = 'dojo_starter-ResourceShareRuleTally',
	ShareRuleKind = 'dojo_starter-ShareRuleKind',
	AreaType = 'dojo_starter-AreaType',
	Biome = 'dojo_starter-Biome',
	Hex = 'dojo_starter-Hex',
	HexArea = 'dojo_starter-HexArea',
	SizeCategory = 'dojo_starter-SizeCategory',
	WorldGenConfig = 'dojo_starter-WorldGenConfig',
	AdventurerCreated = 'dojo_starter-AdventurerCreated',
	AdventurerDied = 'dojo_starter-AdventurerDied',
	AdventurerMoved = 'dojo_starter-AdventurerMoved',
	ConstructionCompleted = 'dojo_starter-ConstructionCompleted',
	ConstructionPlantProcessed = 'dojo_starter-ConstructionPlantProcessed',
	ConstructionRejected = 'dojo_starter-ConstructionRejected',
	ConstructionRepaired = 'dojo_starter-ConstructionRepaired',
	ConstructionStarted = 'dojo_starter-ConstructionStarted',
	ConstructionUpgradeQueued = 'dojo_starter-ConstructionUpgradeQueued',
	ConstructionUpkeepPaid = 'dojo_starter-ConstructionUpkeepPaid',
	BountyPaid = 'dojo_starter-BountyPaid',
	ClaimExpired = 'dojo_starter-ClaimExpired',
	ClaimInitiated = 'dojo_starter-ClaimInitiated',
	ClaimRefunded = 'dojo_starter-ClaimRefunded',
	HexBecameClaimable = 'dojo_starter-HexBecameClaimable',
	HexDefended = 'dojo_starter-HexDefended',
	HexEnergyPaid = 'dojo_starter-HexEnergyPaid',
	ItemsConverted = 'dojo_starter-ItemsConverted',
	RegulatorPolicyUpdated = 'dojo_starter-RegulatorPolicyUpdated',
	RegulatorTicked = 'dojo_starter-RegulatorTicked',
	HarvestingCancelled = 'dojo_starter-HarvestingCancelled',
	HarvestingCompleted = 'dojo_starter-HarvestingCompleted',
	HarvestingRejected = 'dojo_starter-HarvestingRejected',
	HarvestingStarted = 'dojo_starter-HarvestingStarted',
	MineAccessGranted = 'dojo_starter-MineAccessGranted',
	MineAccessRevoked = 'dojo_starter-MineAccessRevoked',
	MineCollapsed = 'dojo_starter-MineCollapsed',
	MineInitialized = 'dojo_starter-MineInitialized',
	MineRepaired = 'dojo_starter-MineRepaired',
	MineStabilized = 'dojo_starter-MineStabilized',
	MiningContinued = 'dojo_starter-MiningContinued',
	MiningExited = 'dojo_starter-MiningExited',
	MiningRejected = 'dojo_starter-MiningRejected',
	MiningStarted = 'dojo_starter-MiningStarted',
	AreaOwnershipAssigned = 'dojo_starter-AreaOwnershipAssigned',
	OwnershipTransferred = 'dojo_starter-OwnershipTransferred',
	ResourceAccessGranted = 'dojo_starter-ResourceAccessGranted',
	ResourceAccessRevoked = 'dojo_starter-ResourceAccessRevoked',
	ResourcePermissionRejected = 'dojo_starter-ResourcePermissionRejected',
	ResourcePolicyUpserted = 'dojo_starter-ResourcePolicyUpserted',
	ResourceShareRuleCleared = 'dojo_starter-ResourceShareRuleCleared',
	ResourceShareRuleSet = 'dojo_starter-ResourceShareRuleSet',
	AreaDiscovered = 'dojo_starter-AreaDiscovered',
	HexDiscovered = 'dojo_starter-HexDiscovered',
	WorldActionRejected = 'dojo_starter-WorldActionRejected',
	WorldGenConfigInitialized = 'dojo_starter-WorldGenConfigInitialized',
	TickOutcome = 'dojo_starter-TickOutcome',
	TickStatus = 'dojo_starter-TickStatus',
}