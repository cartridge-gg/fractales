#[cfg(test)]
mod tests {
    use dojo_starter::libs::coord_codec::{CubeCoord, decode_cube, encode_cube};

    #[test]
    fn coord_codec_roundtrip_origin() {
        let coord = CubeCoord { x: 0, y: 0, z: 0 };
        let encoded_opt: Option<felt252> = encode_cube(coord);
        let encoded = match encoded_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'ENC_NONE');
                0
            },
        };

        let decoded_opt: Option<CubeCoord> = decode_cube(encoded);
        let decoded = match decoded_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'DEC_NONE');
                CubeCoord { x: 0, y: 0, z: 0 }
            },
        };

        assert(decoded == coord, 'ROUNDTRIP0');
    }

    #[test]
    fn coord_codec_roundtrip_non_origin() {
        let coord = CubeCoord { x: 5, y: -2, z: -3 };
        let encoded_opt: Option<felt252> = encode_cube(coord);
        let encoded = match encoded_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'ENC_NONE');
                0
            },
        };

        let decoded_opt: Option<CubeCoord> = decode_cube(encoded);
        let decoded = match decoded_opt {
            Option::Some(value) => value,
            Option::None => {
                assert(1 == 0, 'DEC_NONE');
                CubeCoord { x: 0, y: 0, z: 0 }
            },
        };

        assert(decoded == coord, 'ROUNDTRIP1');
    }

    #[test]
    fn coord_codec_rejects_invalid_cube_sum() {
        let invalid = CubeCoord { x: 3, y: 3, z: 0 };
        match encode_cube(invalid) {
            Option::None => {},
            Option::Some(_) => {
                assert(1 == 0, 'INVALID_SUM');
            },
        }
    }

    #[test]
    fn coord_codec_rejects_out_of_range_felt() {
        // 2^63 is outside the packed range.
        let bad_encoded: felt252 = 9223372036854775808;
        match decode_cube(bad_encoded) {
            Option::None => {},
            Option::Some(_) => {
                assert(1 == 0, 'RANGE_FAIL');
            },
        }
    }
}
