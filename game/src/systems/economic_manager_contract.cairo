const CONVERSION_WINDOW_BLOCKS: u64 = 100_u64;
const DECAY_PERIOD_BLOCKS: u64 = 100_u64;
const CLAIM_TIMEOUT_BLOCKS: u64 = 100_u64;
const CLAIM_GRACE_BLOCKS: u64 = 500_u64;
const CLAIMABLE_DECAY_THRESHOLD: u16 = 80_u16;
const DECAY_RECOVERY_BP: u16 = 20_u16;

#[starknet::interface]
pub trait IEconomicManager<T> {
    fn convert_items_to_energy(
        ref self: T, adventurer_id: felt252, item_id: felt252, quantity: u16,
    ) -> u16;
    fn pay_hex_maintenance(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, amount: u16,
    ) -> bool;
    fn process_hex_decay(ref self: T, hex_coordinate: felt252) -> u16;
    fn initiate_hex_claim(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, energy_offered: u16,
    ) -> bool;
    fn defend_hex_from_claim(
        ref self: T, adventurer_id: felt252, hex_coordinate: felt252, defense_energy: u16,
    ) -> bool;
}

#[dojo::contract]
pub mod economic_manager {
    use super::{
        CLAIMABLE_DECAY_THRESHOLD, CLAIM_GRACE_BLOCKS, CLAIM_TIMEOUT_BLOCKS, CONVERSION_WINDOW_BLOCKS,
        DECAY_PERIOD_BLOCKS, DECAY_RECOVERY_BP, IEconomicManager,
    };
    use core::traits::TryInto;
    use dojo::event::EventStorage;
    use dojo::model::ModelStorage;
    use dojo_starter::events::economic_events::{
        ClaimExpired, ClaimInitiated, ClaimRefunded, HexBecameClaimable, HexDefended, HexEnergyPaid,
        ItemsConverted,
    };
    use dojo_starter::events::ownership_events::OwnershipTransferred;
    use dojo_starter::libs::decay_math::{min_claim_energy, upkeep_for_biome};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{
        AdventurerEconomics, ClaimEscrow, ClaimEscrowExpireOutcome, ClaimEscrowStatus,
        ConversionRate, HexDecayState, derive_hex_claim_id, expire_claim_escrow_once_with_status,
    };
    use dojo_starter::models::inventory::{BackpackItem, Inventory};
    use dojo_starter::models::ownership::AreaOwnership;
    use dojo_starter::models::world::{Hex, derive_area_id};
    use dojo_starter::systems::economic_manager::{
        ClaimInitOutcome, ConvertOutcome, DecayOutcome, DefendOutcome, PayOutcome, convert_transition,
        defend_claim_transition, initiate_claim_transition, pay_maintenance_transition,
        process_decay_transition,
    };
    use starknet::{get_block_info, get_caller_address};

    const U64_MAX_U128: u128 = 18_446_744_073_709_551_615_u128;

    fn saturating_add_u64(lhs: u64, rhs: u64) -> u64 {
        let sum_u128: u128 = lhs.into() + rhs.into();
        if sum_u128 > U64_MAX_U128 {
            18_446_744_073_709_551_615_u64
        } else {
            sum_u128.try_into().unwrap()
        }
    }

    fn settle_expired_claim_if_needed(
        ref world: dojo::world::WorldStorage,
        hex_coordinate: felt252,
        now_block: u64,
        escrow: ClaimEscrow,
    ) -> ClaimEscrow {
        if escrow.status != ClaimEscrowStatus::Active || now_block <= escrow.expiry_block {
            return escrow;
        }

        if escrow.claimant_adventurer_id == 0_felt252 {
            let mut invalid_expired = escrow;
            invalid_expired.status = ClaimEscrowStatus::Expired;
            invalid_expired.energy_locked = 0_u16;
            world.write_model(@invalid_expired);
            return invalid_expired;
        }

        let claimant_before: Adventurer = world.read_model(escrow.claimant_adventurer_id);
        let claimant_economics_before: AdventurerEconomics = world.read_model(escrow.claimant_adventurer_id);
        let expired = expire_claim_escrow_once_with_status(claimant_before, escrow, now_block);

        match expired.outcome {
            ClaimEscrowExpireOutcome::Applied => {
                let refunded = expired.adventurer.energy - claimant_before.energy;
                let mut claimant_economics_after = claimant_economics_before;
                claimant_economics_after.energy_balance = expired.adventurer.energy;
                claimant_economics_after.total_energy_earned = saturating_add_u64(
                    claimant_economics_after.total_energy_earned, refunded.into(),
                );

                world.write_model(@expired.adventurer);
                world.write_model(@claimant_economics_after);
                world.write_model(@expired.escrow);
                world.emit_event(
                    @ClaimExpired {
                        hex: hex_coordinate,
                        claim_id: expired.escrow.claim_id,
                        claimant: expired.escrow.claimant_adventurer_id,
                    },
                );
                world.emit_event(
                    @ClaimRefunded {
                        hex: hex_coordinate,
                        claim_id: expired.escrow.claim_id,
                        claimant: expired.escrow.claimant_adventurer_id,
                        amount: refunded,
                    },
                );
                expired.escrow
            },
            _ => escrow,
        }
    }

    fn sync_hex_area_ownership_controller(
        ref world: dojo::world::WorldStorage,
        hex_coordinate: felt252,
        controller_adventurer_id: felt252,
        claim_block: u64,
        set_claim_block: bool,
    ) {
        let hex: Hex = world.read_model(hex_coordinate);
        let mut idx: u8 = 0_u8;
        loop {
            if idx >= hex.area_count {
                break;
            };

            let area_id = derive_area_id(hex_coordinate, idx);
            let mut ownership: AreaOwnership = world.read_model(area_id);
            ownership.area_id = area_id;
            let previous_owner = ownership.owner_adventurer_id;
            ownership.owner_adventurer_id = controller_adventurer_id;
            if set_claim_block {
                ownership.claim_block = claim_block;
            }
            world.write_model(@ownership);

            if previous_owner != 0_felt252 && previous_owner != controller_adventurer_id {
                world.emit_event(
                    @OwnershipTransferred {
                        area_id,
                        from_adventurer_id: previous_owner,
                        to_adventurer_id: controller_adventurer_id,
                        claim_block: ownership.claim_block,
                    },
                );
            }

            idx += 1_u8;
        };
    }

    #[abi(embed_v0)]
    impl EconomicManagerImpl of IEconomicManager<ContractState> {
        fn convert_items_to_energy(
            ref self: ContractState, adventurer_id: felt252, item_id: felt252, quantity: u16,
        ) -> u16 {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let inventory: Inventory = world.read_model(adventurer_id);
            let mut item: BackpackItem = world.read_model((adventurer_id, item_id));
            item.adventurer_id = adventurer_id;
            item.item_id = item_id;

            let mut rate: ConversionRate = world.read_model(item_id);
            rate.item_type = if rate.item_type == 0_felt252 { item_id } else { rate.item_type };

            let converted = convert_transition(
                adventurer,
                economics,
                caller,
                inventory,
                item,
                rate,
                quantity,
                now_block,
                CONVERSION_WINDOW_BLOCKS,
            );

            match converted.outcome {
                ConvertOutcome::Applied => {
                    world.write_model(@converted.adventurer);
                    world.write_model(@converted.economics);
                    world.write_model(@converted.inventory);
                    world.write_model(@converted.item);
                    world.write_model(@converted.rate);
                    world.emit_event(
                        @ItemsConverted {
                            adventurer_id,
                            item_id,
                            quantity,
                            energy_gained: converted.energy_gained,
                        },
                    );
                    converted.energy_gained
                },
                _ => 0_u16,
            }
        }

        fn pay_hex_maintenance(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, amount: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let adventurer: Adventurer = world.read_model(adventurer_id);
            let economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);

            let paid = pay_maintenance_transition(
                adventurer,
                economics,
                caller,
                state,
                amount,
                upkeep,
                now_block,
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match paid.outcome {
                PayOutcome::Applied => {
                    world.write_model(@paid.adventurer);
                    world.write_model(@paid.economics);
                    world.write_model(@paid.state);
                    world.emit_event(
                        @HexEnergyPaid { hex: hex_coordinate, payer: adventurer_id, amount },
                    );
                    true
                },
                PayOutcome::InsufficientEnergy => {
                    world.write_model(@paid.adventurer);
                    world.write_model(@paid.economics);
                    false
                },
                _ => false,
            }
        }

        fn process_hex_decay(ref self: ContractState, hex_coordinate: felt252) -> u16 {
            let mut world = self.world_default();
            let now_block = get_block_info().unbox().block_number;

            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);

            let processed = process_decay_transition(
                state,
                hex.biome,
                now_block,
                DECAY_PERIOD_BLOCKS,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match processed.outcome {
                DecayOutcome::Applied => {
                    world.write_model(@processed.state);
                    if processed.became_claimable {
                        world.emit_event(
                            @HexBecameClaimable {
                                hex: hex_coordinate,
                                min_energy_to_claim: processed.min_energy_to_claim,
                            },
                        );
                    }
                },
                _ => {},
            }

            processed.state.decay_level
        }

        fn initiate_hex_claim(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, energy_offered: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let claimant: Adventurer = world.read_model(adventurer_id);
            let claimant_economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);
            let min_required_u16 = min_claim_energy(
                upkeep, state.decay_level, CLAIMABLE_DECAY_THRESHOLD,
            );

            let claim_id = derive_hex_claim_id(hex_coordinate);
            let mut escrow: ClaimEscrow = world.read_model(claim_id);
            escrow.claim_id = claim_id;
            escrow.hex_coordinate = hex_coordinate;
            escrow = settle_expired_claim_if_needed(ref world, hex_coordinate, now_block, escrow);

            let initiated = initiate_claim_transition(
                claimant,
                claimant_economics,
                caller,
                state,
                escrow,
                energy_offered,
                now_block,
                CLAIM_TIMEOUT_BLOCKS,
                CLAIM_GRACE_BLOCKS,
                min_required_u16.into(),
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match initiated.outcome {
                ClaimInitOutcome::AppliedPending | ClaimInitOutcome::AppliedImmediate => {
                    world.write_model(@initiated.claimant);
                    world.write_model(@initiated.claimant_economics);
                    world.write_model(@initiated.state);
                    world.write_model(@initiated.escrow);
                    if initiated.outcome == ClaimInitOutcome::AppliedImmediate {
                        sync_hex_area_ownership_controller(
                            ref world,
                            hex_coordinate,
                            initiated.state.owner_adventurer_id,
                            now_block,
                            true,
                        );
                    }
                    world.emit_event(
                        @ClaimInitiated {
                            hex: hex_coordinate,
                            claimant: adventurer_id,
                            claim_id: initiated.escrow.claim_id,
                            energy_locked: initiated.escrow.energy_locked,
                            expiry_block: initiated.escrow.expiry_block,
                        },
                    );
                    true
                },
                _ => false,
            }
        }

        fn defend_hex_from_claim(
            ref self: ContractState, adventurer_id: felt252, hex_coordinate: felt252, defense_energy: u16,
        ) -> bool {
            let mut world = self.world_default();
            let caller = get_caller_address();
            let now_block = get_block_info().unbox().block_number;

            let defender: Adventurer = world.read_model(adventurer_id);
            let defender_economics: AdventurerEconomics = world.read_model(adventurer_id);
            let state: HexDecayState = world.read_model(hex_coordinate);
            let hex: Hex = world.read_model(hex_coordinate);
            let upkeep = upkeep_for_biome(hex.biome);

            let claim_id = derive_hex_claim_id(hex_coordinate);
            let mut escrow: ClaimEscrow = world.read_model(claim_id);
            escrow.claim_id = claim_id;
            escrow.hex_coordinate = hex_coordinate;
            escrow = settle_expired_claim_if_needed(ref world, hex_coordinate, now_block, escrow);

            if escrow.claimant_adventurer_id == 0_felt252 || escrow.status != ClaimEscrowStatus::Active {
                return false;
            }

            let claimant: Adventurer = world.read_model(escrow.claimant_adventurer_id);
            let claimant_economics: AdventurerEconomics = world.read_model(escrow.claimant_adventurer_id);

            let defended = defend_claim_transition(
                defender,
                defender_economics,
                caller,
                state,
                escrow,
                claimant,
                claimant_economics,
                defense_energy,
                now_block,
                upkeep,
                DECAY_RECOVERY_BP,
                CLAIMABLE_DECAY_THRESHOLD,
            );

            match defended.outcome {
                DefendOutcome::Applied => {
                    world.write_model(@defended.defender);
                    world.write_model(@defended.defender_economics);
                    world.write_model(@defended.claimant);
                    world.write_model(@defended.claimant_economics);
                    world.write_model(@defended.state);
                    world.write_model(@defended.escrow);
                    sync_hex_area_ownership_controller(
                        ref world,
                        hex_coordinate,
                        defended.state.owner_adventurer_id,
                        0_u64,
                        false,
                    );
                    world.emit_event(
                        @ClaimRefunded {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                            amount: defended.claimant.energy - claimant.energy,
                        },
                    );
                    world.emit_event(
                        @HexDefended {
                            hex: hex_coordinate,
                            owner: adventurer_id,
                            energy: defense_energy,
                        },
                    );
                    true
                },
                DefendOutcome::InsufficientEnergy => {
                    world.write_model(@defended.defender);
                    world.write_model(@defended.defender_economics);
                    false
                },
                DefendOutcome::ClaimExpired => {
                    world.write_model(@defended.claimant);
                    world.write_model(@defended.claimant_economics);
                    world.write_model(@defended.escrow);
                    world.emit_event(
                        @ClaimExpired {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                        },
                    );
                    world.emit_event(
                        @ClaimRefunded {
                            hex: hex_coordinate,
                            claim_id,
                            claimant: defended.claimant.adventurer_id,
                            amount: defended.claimant.energy - claimant.energy,
                        },
                    );
                    false
                },
                _ => false,
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
