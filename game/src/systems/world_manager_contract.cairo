const ENERGY_PER_HEX_MOVE: u16 = 15_u16;
const ENERGY_PER_EXPLORE: u16 = 25_u16;
const WORLD_GEN_VERSION_ACTIVE: u16 = 1_u16;
const ACTION_DISCOVER_HEX: felt252 = 'DISC_HEX'_felt252;
const ACTION_DISCOVER_AREA: felt252 = 'DISC_AREA'_felt252;
const ACTION_MOVE: felt252 = 'MOVE'_felt252;

#[starknet::interface]
pub trait IWorldManager<T> {
    fn discover_hex(
        ref self: T,
        adventurer_id: felt252,
        hex_coordinate: felt252,
    );
    fn discover_area(
        ref self: T,
        adventurer_id: felt252,
        hex_coordinate: felt252,
        area_index: u8,
    );
    fn move_adventurer(ref self: T, adventurer_id: felt252, to_hex_coordinate: felt252);
}

#[dojo::contract]
pub mod world_manager {
    use super::{
        ACTION_DISCOVER_AREA, ACTION_DISCOVER_HEX, ACTION_MOVE, ENERGY_PER_EXPLORE, ENERGY_PER_HEX_MOVE,
        IWorldManager, WORLD_GEN_VERSION_ACTIVE,
    };
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::adventurer_events::AdventurerMoved;
    use dojo_starter::events::ownership_events::AreaOwnershipAssigned;
    use dojo_starter::events::world_events::{AreaDiscovered, HexDiscovered, WorldActionRejected};
    use dojo_starter::libs::adjacency::is_adjacent;
    use dojo_starter::libs::coord_codec::decode_cube;
    use dojo_starter::libs::world_gen::{
        derive_area_profile_with_config, derive_hex_profile_with_config,
    };
    use dojo_starter::models::adventurer::{Adventurer, can_be_controlled_by, spend_energy};
    use dojo_starter::models::economics::HexDecayState;
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{
        DiscoveryWriteStatus, Hex, HexArea, WorldGenConfig, derive_area_id,
        discover_area_once_with_status, discover_hex_once_with_status, is_valid_area_identity,
        is_valid_area_index,
    };
    use starknet::{get_block_info, get_caller_address};

    fn emit_rejection(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        action: felt252,
        target: felt252,
        reason: felt252,
    ) {
        world.emit_event(
            @WorldActionRejected {
                adventurer_id, action, target, reason,
            },
        );
    }

    #[abi(embed_v0)]
    impl WorldManagerImpl of IWorldManager<ContractState> {
        fn discover_hex(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
        ) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_HEX, hex_coordinate, 'DEAD'_felt252,
                );
                return;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_HEX, hex_coordinate, 'NOT_OWNER'_felt252,
                );
                return;
            }
            let _from = decode_cube(adventurer.current_hex);
            let _to = decode_cube(hex_coordinate);
            match (_from, _to) {
                (Option::Some(from), Option::Some(to)) => {
                    if !is_adjacent(from, to) {
                        emit_rejection(
                            ref world, adventurer_id, ACTION_DISCOVER_HEX, hex_coordinate, 'NOT_ADJ'_felt252,
                        );
                        return;
                    }
                },
                _ => {
                    emit_rejection(
                        ref world, adventurer_id, ACTION_DISCOVER_HEX, hex_coordinate, 'BAD_COORD'_felt252,
                    );
                    return;
                },
            }
            let mut hex: Hex = world.read_model(hex_coordinate);
            hex.coordinate = hex_coordinate;
            let world_gen_config: WorldGenConfig = world.read_model(WORLD_GEN_VERSION_ACTIVE);
            let hex_profile = derive_hex_profile_with_config(hex_coordinate, world_gen_config);

            let block_number = get_block_info().unbox().block_number;
            let discovered = discover_hex_once_with_status(
                hex,
                caller,
                block_number,
                hex_profile.biome,
                hex_profile.area_count,
            );

            match discovered.status {
                DiscoveryWriteStatus::Applied => {
                    let charged = spend_energy(adventurer, ENERGY_PER_EXPLORE);
                    match charged {
                        Option::Some(updated_adventurer) => {
                            world.write_model(@discovered.value);
                            world.write_model(@updated_adventurer);
                            world.emit_event(
                                @HexDiscovered {
                                    hex: discovered.value.coordinate,
                                    biome: discovered.value.biome,
                                    discoverer: caller,
                                },
                            );
                        },
                        Option::None => {
                            emit_rejection(
                                ref world, adventurer_id, ACTION_DISCOVER_HEX, hex_coordinate,
                                'LOW_ENERGY'_felt252,
                            );
                        },
                    }
                },
                DiscoveryWriteStatus::Replay => {},
            }
        }

        fn discover_area(
            ref self: ContractState,
            adventurer_id: felt252,
            hex_coordinate: felt252,
            area_index: u8,
        ) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let block_number = get_block_info().unbox().block_number;
            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'DEAD'_felt252,
                );
                return;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'NOT_OWNER'_felt252,
                );
                return;
            }

            let hex: Hex = world.read_model(hex_coordinate);
            if !hex.is_discovered {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'HEX_UNDISC'_felt252,
                );
                return;
            }
            if !is_valid_area_index(area_index, hex.area_count) {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'AREA_INDEX'_felt252,
                );
                return;
            }

            let mut controller_adventurer_id = adventurer_id;
            let mut controller_claim_block = 0_u64;
            if area_index != 0_u8 {
                let control_area_id = derive_area_id(hex_coordinate, 0_u8);
                let mut control_ownership: AreaOwnership = world.read_model(control_area_id);
                control_ownership.area_id = control_area_id;
                if control_ownership.owner_adventurer_id == 0_felt252 {
                    emit_rejection(
                        ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'CTRL_UNSET'_felt252,
                    );
                    return;
                }
                controller_adventurer_id = control_ownership.owner_adventurer_id;
                controller_claim_block = control_ownership.claim_block;
            }
            let world_gen_config: WorldGenConfig = world.read_model(WORLD_GEN_VERSION_ACTIVE);
            let area_profile = derive_area_profile_with_config(
                hex_coordinate, area_index, hex.biome, world_gen_config,
            );

            let area_id = derive_area_id(hex_coordinate, area_index);
            let mut area: HexArea = world.read_model(area_id);
            area.area_id = area_id;
            area.hex_coordinate = hex_coordinate;
            area.area_index = area_index;

            if !is_valid_area_identity(area) {
                emit_rejection(
                    ref world, adventurer_id, ACTION_DISCOVER_AREA, hex_coordinate, 'BAD_AREA_ID'_felt252,
                );
                return;
            }

            let discovered = discover_area_once_with_status(
                area,
                caller,
                area_profile.area_type,
                area_profile.resource_quality,
                area_profile.size_category,
            );

            match discovered.status {
                DiscoveryWriteStatus::Applied => {
                    world.write_model(@discovered.value);
                    let mut ownership: AreaOwnership = world.read_model(area_id);
                    ownership.area_id = area_id;
                    ownership.owner_adventurer_id = controller_adventurer_id;
                    ownership.discoverer_adventurer_id = adventurer_id;
                    ownership.discovery_block = block_number;
                    ownership.claim_block = controller_claim_block;
                    world.write_model(@ownership);

                    world.emit_event(
                        @AreaOwnershipAssigned {
                            area_id,
                            owner_adventurer_id: ownership.owner_adventurer_id,
                            discoverer_adventurer_id: ownership.discoverer_adventurer_id,
                            claim_block: ownership.claim_block,
                        },
                    );
                    world.emit_event(
                        @AreaDiscovered {
                            area_id: discovered.value.area_id,
                            hex: discovered.value.hex_coordinate,
                            area_type: discovered.value.area_type,
                            discoverer: caller,
                        },
                    );

                    if area_index == 0_u8 {
                        let mut decay_state: HexDecayState = world.read_model(hex_coordinate);
                        decay_state.hex_coordinate = hex_coordinate;
                        if decay_state.owner_adventurer_id == 0_felt252 {
                            decay_state.owner_adventurer_id = controller_adventurer_id;
                            world.write_model(@decay_state);
                        }
                    }
                },
                DiscoveryWriteStatus::Replay => {},
            }
        }

        fn move_adventurer(ref self: ContractState, adventurer_id: felt252, to_hex_coordinate: felt252) {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let adventurer: Adventurer = world.read_model(adventurer_id);
            if !adventurer.is_alive {
                emit_rejection(
                    ref world, adventurer_id, ACTION_MOVE, to_hex_coordinate, 'DEAD'_felt252,
                );
                return;
            }
            if !can_be_controlled_by(adventurer, caller) {
                emit_rejection(
                    ref world, adventurer_id, ACTION_MOVE, to_hex_coordinate, 'NOT_OWNER'_felt252,
                );
                return;
            }

            let _from = decode_cube(adventurer.current_hex);
            let _to = decode_cube(to_hex_coordinate);
            match (_from, _to) {
                (Option::Some(from), Option::Some(to)) => {
                    if !is_adjacent(from, to) {
                        emit_rejection(
                            ref world, adventurer_id, ACTION_MOVE, to_hex_coordinate, 'NOT_ADJ'_felt252,
                        );
                        return;
                    }
                },
                _ => {
                    emit_rejection(
                        ref world, adventurer_id, ACTION_MOVE, to_hex_coordinate, 'BAD_COORD'_felt252,
                    );
                    return;
                },
            }
            let charged = spend_energy(adventurer, ENERGY_PER_HEX_MOVE);
            match charged {
                Option::Some(mut updated) => {
                    let from_hex = updated.current_hex;
                    updated.current_hex = to_hex_coordinate;
                    world.write_model(@updated);
                    world.emit_event(
                        @AdventurerMoved {
                            adventurer_id: updated.adventurer_id,
                            from: from_hex,
                            to: to_hex_coordinate,
                        },
                    );
                },
                Option::None => {
                    emit_rejection(
                        ref world, adventurer_id, ACTION_MOVE, to_hex_coordinate, 'LOW_ENERGY'_felt252,
                    );
                },
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}
