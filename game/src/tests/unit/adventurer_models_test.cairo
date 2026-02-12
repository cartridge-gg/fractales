#[cfg(test)]
mod tests {
    use dojo_starter::models::adventurer::{
        Adventurer, AdventurerWriteStatus, kill_once_with_status, spend_energy,
    };
    use dojo_starter::libs::coord_codec::{CubeCoord, encode_cube};
    use starknet::ContractAddress;

    fn origin_hex() -> felt252 {
        match encode_cube(CubeCoord { x: 0, y: 0, z: 0 }) {
            Option::Some(encoded) => encoded,
            Option::None => {
                assert(1 == 0, 'ORIGIN_HEX_NONE');
                0
            },
        }
    }

    #[test]
    fn adventurer_models_kill_is_monotonic() {
        let alive = Adventurer {
            adventurer_id: 1,
            owner: 10.try_into().unwrap(),
            name: 'ALIVE'_felt252,
            energy: 100_u16,
            max_energy: 100_u16,
            current_hex: origin_hex(),
            activity_locked_until: 77_u64,
            is_alive: true,
        };

        let first = kill_once_with_status(alive);
        assert(first.status == AdventurerWriteStatus::Applied, 'KILL_FIRST_STATUS');
        assert(!first.value.is_alive, 'KILL_FIRST_ALIVE');
        assert(first.value.activity_locked_until == 0_u64, 'KILL_FIRST_LOCK');

        let replay = kill_once_with_status(first.value);
        assert(replay.status == AdventurerWriteStatus::Replay, 'KILL_REPLAY_STATUS');
        assert(!replay.value.is_alive, 'KILL_REPLAY_ALIVE');
        assert(replay.value.activity_locked_until == 0_u64, 'KILL_REPLAY_LOCK');
    }

    #[test]
    fn adventurer_models_spend_energy_requires_alive_and_balance() {
        let alive = Adventurer {
            adventurer_id: 2,
            owner: 20.try_into().unwrap(),
            name: 'ALIVE2'_felt252,
            energy: 30_u16,
            max_energy: 100_u16,
            current_hex: origin_hex(),
            activity_locked_until: 0_u64,
            is_alive: true,
        };

        let spent = spend_energy(alive, 25_u16);
        match spent {
            Option::Some(updated) => assert(updated.energy == 5_u16, 'SPEND_OK_ENERGY'),
            Option::None => assert(1 == 0, 'SPEND_OK_NONE'),
        }

        let overspend = spend_energy(alive, 31_u16);
        assert(overspend.is_none(), 'SPEND_OVER_NONE');

        let dead = Adventurer { is_alive: false, ..alive };
        let dead_spend = spend_energy(dead, 1_u16);
        assert(dead_spend.is_none(), 'SPEND_DEAD_NONE');
    }

    #[test]
    fn adventurer_models_controlled_by_owner_only() {
        let adventurer = Adventurer {
            adventurer_id: 3,
            owner: 30.try_into().unwrap(),
            name: 'OWNER'_felt252,
            energy: 10_u16,
            max_energy: 100_u16,
            current_hex: origin_hex(),
            activity_locked_until: 0_u64,
            is_alive: true,
        };

        let owner: ContractAddress = 30.try_into().unwrap();
        let stranger: ContractAddress = 31.try_into().unwrap();

        assert(
            dojo_starter::models::adventurer::can_be_controlled_by(adventurer, owner),
            'OWNER_ALLOWED',
        );
        assert(
            !dojo_starter::models::adventurer::can_be_controlled_by(adventurer, stranger),
            'STRANGER_BLOCKED',
        );
    }
}
