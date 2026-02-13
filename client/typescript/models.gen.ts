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

// Type definition for `dojo_starter::models::ownership::AreaOwnership` struct
export interface AreaOwnership {
	area_id: BigNumberish;
	owner_adventurer_id: BigNumberish;
	discoverer_adventurer_id: BigNumberish;
	discovery_block: BigNumberish;
	claim_block: BigNumberish;
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

// Type definition for `dojo_starter::models::world::AreaType` enum
export const areaType = [
	'Wilderness',
	'Control',
	'PlantField',
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

export interface SchemaType extends ISchemaType {
	dojo_starter: {
		Adventurer: Adventurer,
		DeathRecord: DeathRecord,
		AdventurerEconomics: AdventurerEconomics,
		ClaimEscrow: ClaimEscrow,
		ConversionRate: ConversionRate,
		HexDecayState: HexDecayState,
		HarvestReservation: HarvestReservation,
		PlantNode: PlantNode,
		BackpackItem: BackpackItem,
		Inventory: Inventory,
		AreaOwnership: AreaOwnership,
		Hex: Hex,
		HexArea: HexArea,
		WorldGenConfig: WorldGenConfig,
		AdventurerCreated: AdventurerCreated,
		AdventurerDied: AdventurerDied,
		AdventurerMoved: AdventurerMoved,
		ClaimExpired: ClaimExpired,
		ClaimInitiated: ClaimInitiated,
		ClaimRefunded: ClaimRefunded,
		HexBecameClaimable: HexBecameClaimable,
		HexDefended: HexDefended,
		HexEnergyPaid: HexEnergyPaid,
		ItemsConverted: ItemsConverted,
		HarvestingCancelled: HarvestingCancelled,
		HarvestingCompleted: HarvestingCompleted,
		HarvestingRejected: HarvestingRejected,
		HarvestingStarted: HarvestingStarted,
		AreaOwnershipAssigned: AreaOwnershipAssigned,
		OwnershipTransferred: OwnershipTransferred,
		AreaDiscovered: AreaDiscovered,
		HexDiscovered: HexDiscovered,
		WorldActionRejected: WorldActionRejected,
		WorldGenConfigInitialized: WorldGenConfigInitialized,
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
		HexDecayState: {
			hex_coordinate: 0,
			owner_adventurer_id: 0,
			current_energy_reserve: 0,
			last_energy_payment_block: 0,
			last_decay_processed_block: 0,
			decay_level: 0,
			claimable_since_block: 0,
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
		AreaOwnership: {
			area_id: 0,
			owner_adventurer_id: 0,
			discoverer_adventurer_id: 0,
			discovery_block: 0,
			claim_block: 0,
		},
		Hex: {
			coordinate: 0,
		biome: new CairoCustomEnum({ 
					Unknown: "",
				Plains: undefined,
				Forest: undefined,
				Mountain: undefined,
				Desert: undefined,
				Swamp: undefined, }),
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
				PlantField: undefined, }),
			is_discovered: false,
			discoverer: "",
			resource_quality: 0,
		size_category: new CairoCustomEnum({ 
					Small: "",
				Medium: undefined,
				Large: undefined, }),
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
		AreaDiscovered: {
			area_id: 0,
			hex: 0,
		area_type: new CairoCustomEnum({ 
					Wilderness: "",
				Control: undefined,
				PlantField: undefined, }),
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
				Swamp: undefined, }),
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
	},
};
export enum ModelsMapping {
	Adventurer = 'dojo_starter-Adventurer',
	DeathRecord = 'dojo_starter-DeathRecord',
	AdventurerEconomics = 'dojo_starter-AdventurerEconomics',
	ClaimEscrow = 'dojo_starter-ClaimEscrow',
	ClaimEscrowStatus = 'dojo_starter-ClaimEscrowStatus',
	ConversionRate = 'dojo_starter-ConversionRate',
	HexDecayState = 'dojo_starter-HexDecayState',
	HarvestReservation = 'dojo_starter-HarvestReservation',
	HarvestReservationStatus = 'dojo_starter-HarvestReservationStatus',
	PlantNode = 'dojo_starter-PlantNode',
	BackpackItem = 'dojo_starter-BackpackItem',
	Inventory = 'dojo_starter-Inventory',
	AreaOwnership = 'dojo_starter-AreaOwnership',
	AreaType = 'dojo_starter-AreaType',
	Biome = 'dojo_starter-Biome',
	Hex = 'dojo_starter-Hex',
	HexArea = 'dojo_starter-HexArea',
	SizeCategory = 'dojo_starter-SizeCategory',
	WorldGenConfig = 'dojo_starter-WorldGenConfig',
	AdventurerCreated = 'dojo_starter-AdventurerCreated',
	AdventurerDied = 'dojo_starter-AdventurerDied',
	AdventurerMoved = 'dojo_starter-AdventurerMoved',
	ClaimExpired = 'dojo_starter-ClaimExpired',
	ClaimInitiated = 'dojo_starter-ClaimInitiated',
	ClaimRefunded = 'dojo_starter-ClaimRefunded',
	HexBecameClaimable = 'dojo_starter-HexBecameClaimable',
	HexDefended = 'dojo_starter-HexDefended',
	HexEnergyPaid = 'dojo_starter-HexEnergyPaid',
	ItemsConverted = 'dojo_starter-ItemsConverted',
	HarvestingCancelled = 'dojo_starter-HarvestingCancelled',
	HarvestingCompleted = 'dojo_starter-HarvestingCompleted',
	HarvestingRejected = 'dojo_starter-HarvestingRejected',
	HarvestingStarted = 'dojo_starter-HarvestingStarted',
	AreaOwnershipAssigned = 'dojo_starter-AreaOwnershipAssigned',
	OwnershipTransferred = 'dojo_starter-OwnershipTransferred',
	AreaDiscovered = 'dojo_starter-AreaDiscovered',
	HexDiscovered = 'dojo_starter-HexDiscovered',
	WorldActionRejected = 'dojo_starter-WorldActionRejected',
	WorldGenConfigInitialized = 'dojo_starter-WorldGenConfigInitialized',
}