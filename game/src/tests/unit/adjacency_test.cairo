#[cfg(test)]
mod tests {
    use dojo_starter::libs::adjacency::{HexDirection, is_adjacent, neighbor};
    use dojo_starter::libs::coord_codec::CubeCoord;

    #[test]
    fn adjacency_neighbors_are_adjacent() {
        let origin = CubeCoord { x: 0, y: 0, z: 0 };

        let n1 = neighbor(origin, HexDirection::PosXNegY);
        let n2 = neighbor(origin, HexDirection::PosXNegZ);
        let n3 = neighbor(origin, HexDirection::PosYNegX);
        let n4 = neighbor(origin, HexDirection::PosYNegZ);
        let n5 = neighbor(origin, HexDirection::PosZNegX);
        let n6 = neighbor(origin, HexDirection::PosZNegY);

        assert(is_adjacent(origin, n1), 'ADJ1');
        assert(is_adjacent(origin, n2), 'ADJ2');
        assert(is_adjacent(origin, n3), 'ADJ3');
        assert(is_adjacent(origin, n4), 'ADJ4');
        assert(is_adjacent(origin, n5), 'ADJ5');
        assert(is_adjacent(origin, n6), 'ADJ6');
    }

    #[test]
    fn adjacency_rejects_non_neighbors() {
        let origin = CubeCoord { x: 0, y: 0, z: 0 };
        let far = CubeCoord { x: 2, y: -1, z: -1 };

        assert(!is_adjacent(origin, far), 'NOT_ADJ');
    }
}
