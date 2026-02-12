use dojo_starter::libs::coord_codec::CubeCoord;

#[derive(Copy, Drop, Serde)]
pub enum HexDirection {
    PosXNegY,
    PosXNegZ,
    PosYNegX,
    PosYNegZ,
    PosZNegX,
    PosZNegY,
}

pub fn neighbor(coord: CubeCoord, direction: HexDirection) -> CubeCoord {
    match direction {
        HexDirection::PosXNegY => CubeCoord { x: coord.x + 1, y: coord.y - 1, z: coord.z },
        HexDirection::PosXNegZ => CubeCoord { x: coord.x + 1, y: coord.y, z: coord.z - 1 },
        HexDirection::PosYNegX => CubeCoord { x: coord.x - 1, y: coord.y + 1, z: coord.z },
        HexDirection::PosYNegZ => CubeCoord { x: coord.x, y: coord.y + 1, z: coord.z - 1 },
        HexDirection::PosZNegX => CubeCoord { x: coord.x - 1, y: coord.y, z: coord.z + 1 },
        HexDirection::PosZNegY => CubeCoord { x: coord.x, y: coord.y - 1, z: coord.z + 1 },
    }
}

pub fn is_adjacent(a: CubeCoord, b: CubeCoord) -> bool {
    let dx = b.x - a.x;
    let dy = b.y - a.y;
    let dz = b.z - a.z;

    if dx + dy + dz != 0 {
        return false;
    }

    let abs_sum = abs_i32(dx) + abs_i32(dy) + abs_i32(dz);
    abs_sum == 2
}

fn abs_i32(value: i32) -> i32 {
    if value < 0 {
        return -value;
    }

    value
}
