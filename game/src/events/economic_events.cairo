#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ItemsConverted {
    #[key]
    pub adventurer_id: felt252,
    pub item_id: felt252,
    pub quantity: u16,
    pub energy_gained: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HexEnergyPaid {
    #[key]
    pub hex: felt252,
    pub payer: felt252,
    pub amount: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HexBecameClaimable {
    #[key]
    pub hex: felt252,
    pub min_energy_to_claim: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ClaimInitiated {
    #[key]
    pub hex: felt252,
    #[key]
    pub claimant: felt252,
    pub claim_id: felt252,
    pub energy_locked: u16,
    pub expiry_block: u64,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ClaimExpired {
    #[key]
    pub hex: felt252,
    pub claim_id: felt252,
    pub claimant: felt252,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct ClaimRefunded {
    #[key]
    pub hex: felt252,
    pub claim_id: felt252,
    pub claimant: felt252,
    pub amount: u16,
}

#[derive(Copy, Drop, Serde)]
#[dojo::event]
pub struct HexDefended {
    #[key]
    pub hex: felt252,
    pub owner: felt252,
    pub energy: u16,
}
