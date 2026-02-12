use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum Biome {
    #[default]
    Unknown,
    Plains,
    Forest,
    Mountain,
    Desert,
    Swamp,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum AreaType {
    #[default]
    Wilderness,
    Control,
    PlantField,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum SizeCategory {
    #[default]
    Small,
    Medium,
    Large,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Hex {
    #[key]
    pub coordinate: felt252,
    pub biome: Biome,
    pub is_discovered: bool,
    pub discovery_block: u64,
    pub discoverer: ContractAddress,
    pub area_count: u8,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct HexArea {
    #[key]
    pub area_id: felt252,
    pub hex_coordinate: felt252,
    pub area_index: u8,
    pub area_type: AreaType,
    pub is_discovered: bool,
    pub discoverer: ContractAddress,
    pub resource_quality: u16,
    pub size_category: SizeCategory,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct WorldGenConfig {
    #[key]
    pub generation_version: u16,
    pub global_seed: felt252,
    pub biome_scale_bp: u16,
    pub area_scale_bp: u16,
    pub plant_scale_bp: u16,
    pub biome_octaves: u8,
    pub area_octaves: u8,
    pub plant_octaves: u8,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug, DojoStore, Default)]
pub enum DiscoveryWriteStatus {
    #[default]
    Replay,
    Applied,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct HexDiscoveryResult {
    pub value: Hex,
    pub status: DiscoveryWriteStatus,
}

#[derive(Copy, Drop, Serde, Debug)]
pub struct AreaDiscoveryResult {
    pub value: HexArea,
    pub status: DiscoveryWriteStatus,
}

pub fn derive_area_id(hex_coordinate: felt252, area_index: u8) -> felt252 {
    let area_index_felt: felt252 = area_index.into();
    let (hashed, _, _) = core::poseidon::hades_permutation(
        hex_coordinate, area_index_felt, 'AREA_ID_V1'_felt252,
    );
    hashed
}

pub fn is_valid_area_index(area_index: u8, area_count: u8) -> bool {
    area_index < area_count
}

pub fn is_valid_area_identity(area: HexArea) -> bool {
    area.area_id == derive_area_id(area.hex_coordinate, area.area_index)
}

pub fn discover_hex_once_with_status(
    mut hex: Hex,
    discoverer: ContractAddress,
    discovery_block: u64,
    biome: Biome,
    area_count: u8,
) -> HexDiscoveryResult {
    if hex.is_discovered {
        return HexDiscoveryResult { value: hex, status: DiscoveryWriteStatus::Replay };
    }

    hex.is_discovered = true;
    hex.discovery_block = discovery_block;
    hex.discoverer = discoverer;
    hex.biome = biome;
    hex.area_count = area_count;

    HexDiscoveryResult { value: hex, status: DiscoveryWriteStatus::Applied }
}

pub fn discover_area_once_with_status(
    mut area: HexArea,
    discoverer: ContractAddress,
    area_type: AreaType,
    resource_quality: u16,
    size_category: SizeCategory,
) -> AreaDiscoveryResult {
    if area.is_discovered {
        return AreaDiscoveryResult { value: area, status: DiscoveryWriteStatus::Replay };
    }

    area.is_discovered = true;
    area.discoverer = discoverer;
    area.area_type = area_type;
    area.resource_quality = resource_quality;
    area.size_category = size_category;

    AreaDiscoveryResult { value: area, status: DiscoveryWriteStatus::Applied }
}

pub fn discover_hex_once(
    mut hex: Hex,
    discoverer: ContractAddress,
    discovery_block: u64,
    biome: Biome,
    area_count: u8,
) -> Hex {
    discover_hex_once_with_status(hex, discoverer, discovery_block, biome, area_count).value
}

pub fn discover_area_once(
    mut area: HexArea,
    discoverer: ContractAddress,
    area_type: AreaType,
    resource_quality: u16,
    size_category: SizeCategory,
) -> HexArea {
    discover_area_once_with_status(area, discoverer, area_type, resource_quality, size_category).value
}
