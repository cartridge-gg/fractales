#[cfg(test)]
mod tests {
    use dojo::event::Event;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_snf_test::{
        ContractDef, ContractDefTrait, NamespaceDef, TestResource, WorldStorageTestTrait,
        get_default_caller_address, set_block_number, spawn_test_world,
    };
    use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};
    use dojo_starter::events::economic_events::HexEnergyPaid;
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use dojo_starter::models::adventurer::Adventurer;
    use dojo_starter::models::economics::{AdventurerEconomics, HexDecayState};
    use dojo_starter::systems::economic_manager_contract::{
        IEconomicManagerDispatcher, IEconomicManagerDispatcherTrait,
    };
    use dojo_starter::systems::world_manager_contract::{
        IWorldManagerDispatcher, IWorldManagerDispatcherTrait,
    };

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "dojo_starter",
            resources: [
                TestResource::Model("Adventurer"),
                TestResource::Model("AdventurerEconomics"),
                TestResource::Model("Hex"),
                TestResource::Model("WorldGenConfig"),
                TestResource::Model("HexArea"),
                TestResource::Model("AreaOwnership"),
                TestResource::Model("HexDecayState"),
                TestResource::Event("HexDiscovered"),
                TestResource::Event("AreaDiscovered"),
                TestResource::Event("AreaOwnershipAssigned"),
                TestResource::Event("AdventurerMoved"),
                TestResource::Event("WorldActionRejected"),
                TestResource::Event("HexEnergyPaid"),
                TestResource::Contract("world_manager"),
                TestResource::Contract("economic_manager"),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"dojo_starter", @"world_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
            ContractDefTrait::new(@"dojo_starter", @"economic_manager")
                .with_writer_of([dojo::utils::bytearray_hash(@"dojo_starter")].span()),
        ]
            .span()
    }

    fn encoded_cube(coord: CubeCoord) -> felt252 {
        match encode_cube(coord) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'W_ECO_ENC_NONE');
                0
            },
        }
    }

    fn setup_actor(
        ref world: dojo::world::WorldStorage,
        adventurer_id: felt252,
        owner: starknet::ContractAddress,
        energy: u16,
        hex_coordinate: felt252,
    ) {
        world.write_model_test(
            @Adventurer {
                adventurer_id,
                owner,
                name: 'W_ECO'_felt252,
                energy,
                max_energy: energy,
                current_hex: hex_coordinate,
                activity_locked_until: 0_u64,
                is_alive: true,
            },
        );
        world.write_model_test(
            @AdventurerEconomics {
                adventurer_id,
                energy_balance: energy,
                total_energy_spent: 0_u64,
                total_energy_earned: 0_u64,
                last_regen_block: 0_u64,
            },
        );
    }

    #[test]
    fn world_economy_bridge_integration_control_discovery_initializes_hex_decay_owner() {
        let caller = get_default_caller_address();
        set_block_number(0_u64);
        let mut world = spawn_test_world([namespace_def()].span());
        world.sync_perms_and_inits(contract_defs());
        let mut spy = spy_events();

        let (world_address, _) = world.dns(@"world_manager").unwrap();
        let world_manager = IWorldManagerDispatcher { contract_address: world_address };
        let (economic_address, _) = world.dns(@"economic_manager").unwrap();
        let economic_manager = IEconomicManagerDispatcher { contract_address: economic_address };

        let adventurer_id = 9701_felt252;
        let origin = encoded_cube(CubeCoord { x: 0, y: 0, z: 0 });
        let target = encoded_cube(CubeCoord { x: 1, y: -1, z: 0 });
        setup_actor(ref world, adventurer_id, caller, 100_u16, origin);

        world_manager.discover_hex(adventurer_id, target);
        world_manager.move_adventurer(adventurer_id, target);
        world_manager.discover_area(adventurer_id, target, 0_u8);

        let state_before_pay: HexDecayState = world.read_model(target);
        assert(state_before_pay.hex_coordinate == target, 'W_ECO_STATE_KEY');
        assert(state_before_pay.owner_adventurer_id == adventurer_id, 'W_ECO_STATE_OWNER');
        assert(state_before_pay.current_energy_reserve == 0_u32, 'W_ECO_STATE_RESV0');

        let paid = economic_manager.pay_hex_maintenance(adventurer_id, target, 10_u16);
        assert(paid, 'W_ECO_PAY_OK');

        let actor_after_pay: Adventurer = world.read_model(adventurer_id);
        let state_after_pay: HexDecayState = world.read_model(target);
        assert(actor_after_pay.energy == 50_u16, 'W_ECO_PAY_ENERGY');
        assert(state_after_pay.owner_adventurer_id == adventurer_id, 'W_ECO_PAY_OWNER');
        assert(state_after_pay.current_energy_reserve == 10_u32, 'W_ECO_PAY_RESV');
        assert(state_after_pay.last_energy_payment_block == 0_u64, 'W_ECO_PAY_BLOCK');

        let events = spy.get_events().emitted_by(world.dispatcher.contract_address);
        let paid_selector = Event::<HexEnergyPaid>::selector(world.namespace_hash);
        let mut paid_count: usize = 0;
        let mut idx: usize = 0;
        loop {
            if idx == events.events.len() {
                break;
            };
            let (_, event) = events.events.at(idx);
            if event.keys.len() >= 2_usize && event.keys.at(0) == @selector!("EventEmitted")
                && event.keys.at(1) == @paid_selector {
                paid_count += 1;
            }
            idx += 1;
        };

        assert(paid_count == 1_usize, 'W_ECO_PAY_EVT');
    }
}
