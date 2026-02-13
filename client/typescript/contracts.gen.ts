import { DojoProvider, DojoCall } from "@dojoengine/core";
import { Account, AccountInterface, BigNumberish, CairoOption, CairoCustomEnum } from "starknet";
import * as models from "./models.gen";

export function setupWorld(provider: DojoProvider) {

	const build_adventurer_manager_consumeEnergy_calldata = (adventurerId: BigNumberish, amount: BigNumberish): DojoCall => {
		return {
			contractName: "adventurer_manager",
			entrypoint: "consume_energy",
			calldata: [adventurerId, amount],
		};
	};

	const adventurer_manager_consumeEnergy = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, amount: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_adventurer_manager_consumeEnergy_calldata(adventurerId, amount),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_adventurer_manager_createAdventurer_calldata = (name: BigNumberish): DojoCall => {
		return {
			contractName: "adventurer_manager",
			entrypoint: "create_adventurer",
			calldata: [name],
		};
	};

	const adventurer_manager_createAdventurer = async (snAccount: Account | AccountInterface, name: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_adventurer_manager_createAdventurer_calldata(name),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_adventurer_manager_killAdventurer_calldata = (adventurerId: BigNumberish, cause: BigNumberish): DojoCall => {
		return {
			contractName: "adventurer_manager",
			entrypoint: "kill_adventurer",
			calldata: [adventurerId, cause],
		};
	};

	const adventurer_manager_killAdventurer = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, cause: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_adventurer_manager_killAdventurer_calldata(adventurerId, cause),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_adventurer_manager_regenerateEnergy_calldata = (adventurerId: BigNumberish): DojoCall => {
		return {
			contractName: "adventurer_manager",
			entrypoint: "regenerate_energy",
			calldata: [adventurerId],
		};
	};

	const adventurer_manager_regenerateEnergy = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_adventurer_manager_regenerateEnergy_calldata(adventurerId),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_economic_manager_convertItemsToEnergy_calldata = (adventurerId: BigNumberish, itemId: BigNumberish, quantity: BigNumberish): DojoCall => {
		return {
			contractName: "economic_manager",
			entrypoint: "convert_items_to_energy",
			calldata: [adventurerId, itemId, quantity],
		};
	};

	const economic_manager_convertItemsToEnergy = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, itemId: BigNumberish, quantity: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_economic_manager_convertItemsToEnergy_calldata(adventurerId, itemId, quantity),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_economic_manager_defendHexFromClaim_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, defenseEnergy: BigNumberish): DojoCall => {
		return {
			contractName: "economic_manager",
			entrypoint: "defend_hex_from_claim",
			calldata: [adventurerId, hexCoordinate, defenseEnergy],
		};
	};

	const economic_manager_defendHexFromClaim = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, defenseEnergy: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_economic_manager_defendHexFromClaim_calldata(adventurerId, hexCoordinate, defenseEnergy),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_economic_manager_initiateHexClaim_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, energyOffered: BigNumberish): DojoCall => {
		return {
			contractName: "economic_manager",
			entrypoint: "initiate_hex_claim",
			calldata: [adventurerId, hexCoordinate, energyOffered],
		};
	};

	const economic_manager_initiateHexClaim = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, energyOffered: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_economic_manager_initiateHexClaim_calldata(adventurerId, hexCoordinate, energyOffered),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_economic_manager_payHexMaintenance_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, amount: BigNumberish): DojoCall => {
		return {
			contractName: "economic_manager",
			entrypoint: "pay_hex_maintenance",
			calldata: [adventurerId, hexCoordinate, amount],
		};
	};

	const economic_manager_payHexMaintenance = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, amount: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_economic_manager_payHexMaintenance_calldata(adventurerId, hexCoordinate, amount),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_economic_manager_processHexDecay_calldata = (hexCoordinate: BigNumberish): DojoCall => {
		return {
			contractName: "economic_manager",
			entrypoint: "process_hex_decay",
			calldata: [hexCoordinate],
		};
	};

	const economic_manager_processHexDecay = async (snAccount: Account | AccountInterface, hexCoordinate: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_economic_manager_processHexDecay_calldata(hexCoordinate),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_harvesting_manager_cancelHarvesting_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish): DojoCall => {
		return {
			contractName: "harvesting_manager",
			entrypoint: "cancel_harvesting",
			calldata: [adventurerId, hexCoordinate, areaId, plantId],
		};
	};

	const harvesting_manager_cancelHarvesting = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_harvesting_manager_cancelHarvesting_calldata(adventurerId, hexCoordinate, areaId, plantId),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_harvesting_manager_completeHarvesting_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish): DojoCall => {
		return {
			contractName: "harvesting_manager",
			entrypoint: "complete_harvesting",
			calldata: [adventurerId, hexCoordinate, areaId, plantId],
		};
	};

	const harvesting_manager_completeHarvesting = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_harvesting_manager_completeHarvesting_calldata(adventurerId, hexCoordinate, areaId, plantId),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_harvesting_manager_initHarvesting_calldata = (hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish): DojoCall => {
		return {
			contractName: "harvesting_manager",
			entrypoint: "init_harvesting",
			calldata: [hexCoordinate, areaId, plantId],
		};
	};

	const harvesting_manager_initHarvesting = async (snAccount: Account | AccountInterface, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_harvesting_manager_initHarvesting_calldata(hexCoordinate, areaId, plantId),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_harvesting_manager_inspectPlant_calldata = (hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish): DojoCall => {
		return {
			contractName: "harvesting_manager",
			entrypoint: "inspect_plant",
			calldata: [hexCoordinate, areaId, plantId],
		};
	};

	const harvesting_manager_inspectPlant = async (hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish) => {
		try {
			return await provider.call("dojo_starter", build_harvesting_manager_inspectPlant_calldata(hexCoordinate, areaId, plantId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_harvesting_manager_startHarvesting_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish, amount: BigNumberish): DojoCall => {
		return {
			contractName: "harvesting_manager",
			entrypoint: "start_harvesting",
			calldata: [adventurerId, hexCoordinate, areaId, plantId, amount],
		};
	};

	const harvesting_manager_startHarvesting = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaId: BigNumberish, plantId: BigNumberish, amount: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_harvesting_manager_startHarvesting_calldata(adventurerId, hexCoordinate, areaId, plantId, amount),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_ownership_manager_getOwner_calldata = (areaId: BigNumberish): DojoCall => {
		return {
			contractName: "ownership_manager",
			entrypoint: "get_owner",
			calldata: [areaId],
		};
	};

	const ownership_manager_getOwner = async (areaId: BigNumberish) => {
		try {
			return await provider.call("dojo_starter", build_ownership_manager_getOwner_calldata(areaId));
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_ownership_manager_transferOwnership_calldata = (areaId: BigNumberish, toAdventurerId: BigNumberish): DojoCall => {
		return {
			contractName: "ownership_manager",
			entrypoint: "transfer_ownership",
			calldata: [areaId, toAdventurerId],
		};
	};

	const ownership_manager_transferOwnership = async (snAccount: Account | AccountInterface, areaId: BigNumberish, toAdventurerId: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_ownership_manager_transferOwnership_calldata(areaId, toAdventurerId),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_world_gen_manager_getActiveWorldGenConfig_calldata = (): DojoCall => {
		return {
			contractName: "world_gen_manager",
			entrypoint: "get_active_world_gen_config",
			calldata: [],
		};
	};

	const world_gen_manager_getActiveWorldGenConfig = async () => {
		try {
			return await provider.call("dojo_starter", build_world_gen_manager_getActiveWorldGenConfig_calldata());
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_world_gen_manager_initializeActiveWorldGenConfig_calldata = (globalSeed: BigNumberish, biomeScaleBp: BigNumberish, areaScaleBp: BigNumberish, plantScaleBp: BigNumberish, biomeOctaves: BigNumberish, areaOctaves: BigNumberish, plantOctaves: BigNumberish): DojoCall => {
		return {
			contractName: "world_gen_manager",
			entrypoint: "initialize_active_world_gen_config",
			calldata: [globalSeed, biomeScaleBp, areaScaleBp, plantScaleBp, biomeOctaves, areaOctaves, plantOctaves],
		};
	};

	const world_gen_manager_initializeActiveWorldGenConfig = async (snAccount: Account | AccountInterface, globalSeed: BigNumberish, biomeScaleBp: BigNumberish, areaScaleBp: BigNumberish, plantScaleBp: BigNumberish, biomeOctaves: BigNumberish, areaOctaves: BigNumberish, plantOctaves: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_world_gen_manager_initializeActiveWorldGenConfig_calldata(globalSeed, biomeScaleBp, areaScaleBp, plantScaleBp, biomeOctaves, areaOctaves, plantOctaves),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_world_manager_discoverArea_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaIndex: BigNumberish): DojoCall => {
		return {
			contractName: "world_manager",
			entrypoint: "discover_area",
			calldata: [adventurerId, hexCoordinate, areaIndex],
		};
	};

	const world_manager_discoverArea = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish, areaIndex: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_world_manager_discoverArea_calldata(adventurerId, hexCoordinate, areaIndex),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_world_manager_discoverHex_calldata = (adventurerId: BigNumberish, hexCoordinate: BigNumberish): DojoCall => {
		return {
			contractName: "world_manager",
			entrypoint: "discover_hex",
			calldata: [adventurerId, hexCoordinate],
		};
	};

	const world_manager_discoverHex = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, hexCoordinate: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_world_manager_discoverHex_calldata(adventurerId, hexCoordinate),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};

	const build_world_manager_moveAdventurer_calldata = (adventurerId: BigNumberish, toHexCoordinate: BigNumberish): DojoCall => {
		return {
			contractName: "world_manager",
			entrypoint: "move_adventurer",
			calldata: [adventurerId, toHexCoordinate],
		};
	};

	const world_manager_moveAdventurer = async (snAccount: Account | AccountInterface, adventurerId: BigNumberish, toHexCoordinate: BigNumberish) => {
		try {
			return await provider.execute(
				snAccount,
				build_world_manager_moveAdventurer_calldata(adventurerId, toHexCoordinate),
				"dojo_starter",
			);
		} catch (error) {
			console.error(error);
			throw error;
		}
	};



	return {
		adventurer_manager: {
			consumeEnergy: adventurer_manager_consumeEnergy,
			buildConsumeEnergyCalldata: build_adventurer_manager_consumeEnergy_calldata,
			createAdventurer: adventurer_manager_createAdventurer,
			buildCreateAdventurerCalldata: build_adventurer_manager_createAdventurer_calldata,
			killAdventurer: adventurer_manager_killAdventurer,
			buildKillAdventurerCalldata: build_adventurer_manager_killAdventurer_calldata,
			regenerateEnergy: adventurer_manager_regenerateEnergy,
			buildRegenerateEnergyCalldata: build_adventurer_manager_regenerateEnergy_calldata,
		},
		economic_manager: {
			convertItemsToEnergy: economic_manager_convertItemsToEnergy,
			buildConvertItemsToEnergyCalldata: build_economic_manager_convertItemsToEnergy_calldata,
			defendHexFromClaim: economic_manager_defendHexFromClaim,
			buildDefendHexFromClaimCalldata: build_economic_manager_defendHexFromClaim_calldata,
			initiateHexClaim: economic_manager_initiateHexClaim,
			buildInitiateHexClaimCalldata: build_economic_manager_initiateHexClaim_calldata,
			payHexMaintenance: economic_manager_payHexMaintenance,
			buildPayHexMaintenanceCalldata: build_economic_manager_payHexMaintenance_calldata,
			processHexDecay: economic_manager_processHexDecay,
			buildProcessHexDecayCalldata: build_economic_manager_processHexDecay_calldata,
		},
		harvesting_manager: {
			cancelHarvesting: harvesting_manager_cancelHarvesting,
			buildCancelHarvestingCalldata: build_harvesting_manager_cancelHarvesting_calldata,
			completeHarvesting: harvesting_manager_completeHarvesting,
			buildCompleteHarvestingCalldata: build_harvesting_manager_completeHarvesting_calldata,
			initHarvesting: harvesting_manager_initHarvesting,
			buildInitHarvestingCalldata: build_harvesting_manager_initHarvesting_calldata,
			inspectPlant: harvesting_manager_inspectPlant,
			buildInspectPlantCalldata: build_harvesting_manager_inspectPlant_calldata,
			startHarvesting: harvesting_manager_startHarvesting,
			buildStartHarvestingCalldata: build_harvesting_manager_startHarvesting_calldata,
		},
		ownership_manager: {
			getOwner: ownership_manager_getOwner,
			buildGetOwnerCalldata: build_ownership_manager_getOwner_calldata,
			transferOwnership: ownership_manager_transferOwnership,
			buildTransferOwnershipCalldata: build_ownership_manager_transferOwnership_calldata,
		},
		world_gen_manager: {
			getActiveWorldGenConfig: world_gen_manager_getActiveWorldGenConfig,
			buildGetActiveWorldGenConfigCalldata: build_world_gen_manager_getActiveWorldGenConfig_calldata,
			initializeActiveWorldGenConfig: world_gen_manager_initializeActiveWorldGenConfig,
			buildInitializeActiveWorldGenConfigCalldata: build_world_gen_manager_initializeActiveWorldGenConfig_calldata,
		},
		world_manager: {
			discoverArea: world_manager_discoverArea,
			buildDiscoverAreaCalldata: build_world_manager_discoverArea_calldata,
			discoverHex: world_manager_discoverHex,
			buildDiscoverHexCalldata: build_world_manager_discoverHex_calldata,
			moveAdventurer: world_manager_moveAdventurer,
			buildMoveAdventurerCalldata: build_world_manager_moveAdventurer_calldata,
		},
	};
}