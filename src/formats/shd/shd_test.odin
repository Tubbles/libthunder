package shd

// Synthetic-fixture tests: hand-built shadow byte runs, no game data.

import "core:testing"

// A 3 x 2 tilepoint grid has 2 x 1 tiles, so 32 shadow samples in an
// 8 x 4 grid.
@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	data: [32]u8
	data[0] = SHADOWED
	data[9] = SHADOWED
	shadow_map, error := parse(data[:], 3, 2)
	defer destroy(&shadow_map)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, shadow_map.width, 8)
	testing.expect_value(t, shadow_map.height, 4)
	testing.expect_value(t, len(shadow_map.samples), 32)
	testing.expect_value(t, sample(&shadow_map, 0, 0), SHADOWED)
	testing.expect_value(t, sample(&shadow_map, 1, 1), SHADOWED)
	testing.expect_value(t, sample(&shadow_map, 2, 1), 0)
	testing.expect_value(t, sample(&shadow_map, 8, 0), 0)
	testing.expect_value(t, sample(&shadow_map, 0, -1), 0)
}

@(test)
length_mismatch_is_rejected :: proc(t: ^testing.T) {
	data: [31]u8
	shadow_map, error := parse(data[:], 3, 2)
	testing.expect_value(t, error, Error.Length_Mismatch)
	testing.expect_value(t, len(shadow_map.samples), 0)
	_, trailing_error := parse(data[:16], 3, 2)
	testing.expect_value(t, trailing_error, Error.Length_Mismatch)
}

@(test)
degenerate_dimensions_are_rejected :: proc(t: ^testing.T) {
	data: [16]u8
	_, error := parse(data[:], 1, 2)
	testing.expect_value(t, error, Error.Invalid_Dimensions)
	_, zero_error := parse(data[:], 0, 0)
	testing.expect_value(t, zero_error, Error.Invalid_Dimensions)
}

// Dimensions whose tile product wraps 32-bit arithmetic must not pass
// the length check; the validation runs in i64.
@(test)
dimension_product_wrap_is_rejected :: proc(t: ^testing.T) {
	data: [16]u8
	_, error := parse(data[:], 0x4000_0002, 2)
	testing.expect_value(t, error, Error.Length_Mismatch)
}
