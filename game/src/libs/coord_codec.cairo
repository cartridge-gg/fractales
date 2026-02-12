#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub struct CubeCoord {
    pub x: i32,
    pub y: i32,
    pub z: i32,
}

const AXIS_OFFSET: i32 = 1048576;
const AXIS_MASK: u64 = 2097151;
const MAX_PACKED: u64 = 9223372036854775807;
const PACK_X_MULT: u64 = 4398046511104; // 2^42
const PACK_Y_MULT: u64 = 2097152; // 2^21
const PACK_RANGE: u64 = 2097152; // 2^21

pub fn is_valid_cube(coord: CubeCoord) -> bool {
    coord.x + coord.y + coord.z == 0
}

fn to_packed_axis(value: i32) -> Option<u64> {
    if value < -AXIS_OFFSET || value > AXIS_OFFSET - 1 {
        return Option::None;
    }

    let shifted: i32 = value + AXIS_OFFSET;
    Option::Some(shifted.try_into().unwrap())
}

pub fn encode_cube(coord: CubeCoord) -> Option<felt252> {
    if !is_valid_cube(coord) {
        return Option::None;
    }

    let x = match to_packed_axis(coord.x) {
        Option::Some(value) => value,
        Option::None => {
            return Option::None;
        },
    };
    let y = match to_packed_axis(coord.y) {
        Option::Some(value) => value,
        Option::None => {
            return Option::None;
        },
    };
    let z = match to_packed_axis(coord.z) {
        Option::Some(value) => value,
        Option::None => {
            return Option::None;
        },
    };

    let packed: u64 = (x * PACK_X_MULT) + (y * PACK_Y_MULT) + z;
    Option::Some(packed.into())
}

pub fn decode_cube(encoded: felt252) -> Option<CubeCoord> {
    let packed_u128_opt: Option<u128> = encoded.try_into();
    let packed_u128 = match packed_u128_opt {
        Option::Some(value) => value,
        Option::None => {
            return Option::None;
        },
    };

    if packed_u128 > MAX_PACKED.into() {
        return Option::None;
    }

    let packed: u64 = packed_u128.try_into().unwrap();

    let x_shifted: u64 = packed / PACK_X_MULT;
    let y_shifted: u64 = (packed / PACK_Y_MULT) % PACK_RANGE;
    let z_shifted: u64 = packed % PACK_RANGE;

    if x_shifted > AXIS_MASK || y_shifted > AXIS_MASK || z_shifted > AXIS_MASK {
        return Option::None;
    }

    let x: i32 = x_shifted.try_into().unwrap();
    let y: i32 = y_shifted.try_into().unwrap();
    let z: i32 = z_shifted.try_into().unwrap();

    let coord = CubeCoord { x: x - AXIS_OFFSET, y: y - AXIS_OFFSET, z: z - AXIS_OFFSET };

    if !is_valid_cube(coord) {
        return Option::None;
    }

    Option::Some(coord)
}
