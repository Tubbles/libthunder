package w3e

// Synthetic-fixture tests: hand-built w3e byte streams, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_f32 :: proc(buffer: ^[dynamic]u8, value: f32) {
	test_append_u32(buffer, transmute(u32)value)
}

// Magic, version 11, tileset 'L', two ground ids, one cliff id, a
// 3 x 2 tilepoint grid.
@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	append(&file, "W3E!")
	test_append_u32(&file, 11)
	append(&file, 'L')
	test_append_u32(&file, 0)
	test_append_u32(&file, 2)
	append(&file, "Ldrt")
	append(&file, "Lgrs")
	test_append_u32(&file, 1)
	append(&file, "CLdi")
	test_append_u32(&file, 3)
	test_append_u32(&file, 2)
	test_append_f32(&file, -128)
	test_append_f32(&file, -64)
	// Tilepoint 0: height 8192, water 8192 with the edge bit, ground
	// texture 4 with the water flag, variation 9, cliff variation 12,
	// cliff level 6, cliff texture 1.
	append(&file, 0x00, 0x20, 0x00, 0x60, 0x44, 0xC9, 0x16)
	// Five filler tilepoints.
	for _ in 0 ..< 5 {
		append(&file, 0x00, 0x20, 0x00, 0x20, 0x00, 0x00, 0x02)
	}
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	environment, error := parse(file[:])
	defer destroy(&environment)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, environment.tileset, 'L')
	testing.expect_value(t, environment.is_custom_tileset, false)
	testing.expect_value(t, len(environment.ground_tileset_ids), 2)
	testing.expect_value(t, environment.ground_tileset_ids[0], [4]u8{'L', 'd', 'r', 't'})
	testing.expect_value(t, environment.ground_tileset_ids[1], [4]u8{'L', 'g', 'r', 's'})
	testing.expect_value(t, len(environment.cliff_tileset_ids), 1)
	testing.expect_value(t, environment.cliff_tileset_ids[0], [4]u8{'C', 'L', 'd', 'i'})
	testing.expect_value(t, environment.width, 3)
	testing.expect_value(t, environment.height, 2)
	testing.expect_value(t, environment.left, -128)
	testing.expect_value(t, environment.bottom, -64)
	testing.expect_value(t, len(environment.tilepoints), 6)

	point := tilepoint(&environment, 0, 0)
	testing.expect_value(t, point.ground_height, 8192)
	testing.expect_value(t, point.water_level, 8192)
	testing.expect_value(t, point.edge_flag, true)
	testing.expect_value(t, point.ground_texture, 4)
	testing.expect_value(t, point.flags, Tilepoint_Flags{.Water})
	testing.expect_value(t, point.variation, 9)
	testing.expect_value(t, point.cliff_variation, 12)
	testing.expect_value(t, point.cliff_level, 6)
	testing.expect_value(t, point.cliff_texture, 1)

	filler := tilepoint(&environment, 2, 1)
	testing.expect_value(t, filler.edge_flag, false)
	testing.expect_value(t, filler.flags, Tilepoint_Flags{})
	testing.expect_value(t, filler.cliff_level, 2)
}

@(test)
bad_magic_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[0] = 'X'
	environment, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Magic)
	testing.expect_value(t, len(environment.tilepoints), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[4] = 12
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

@(test)
truncated_header_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 0 ..< 33 {
		_, error := parse(file[:length])
		if error == .None {
			testing.fail_now(t, "truncated header parsed without error")
		}
	}
}

// A ground-tileset count larger than the file must fail before any
// allocation happens.
@(test)
oversized_list_count_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[13] = 0xFF
	file[14] = 0xFF
	file[15] = 0xFF
	file[16] = 0xFF
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_List_Count)
}

@(test)
tilepoint_count_mismatch_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	_, error := parse(file[:len(file) - 7])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
	_, trailing_error := parse(file[:len(file) - 3])
	testing.expect_value(t, trailing_error, Error.Invalid_Dimensions)
}

@(test)
dimension_product_wrap_is_rejected :: proc(t: ^testing.T) {
	// 0x8000_0001 * 2 * 7 wraps to 14 in 32-bit int arithmetic, which
	// would match the 14 record bytes below; the i64 validation must
	// reject it on every target.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "W3E!")
	test_append_u32(&file, 11)
	append(&file, 'L')
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0x8000_0001)
	test_append_u32(&file, 2)
	test_append_f32(&file, 0)
	test_append_f32(&file, 0)
	for _ in 0 ..< 14 {
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
}

@(test)
zero_dimension_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "W3E!")
	test_append_u32(&file, 11)
	append(&file, 'L')
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 3)
	test_append_f32(&file, 0)
	test_append_f32(&file, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
}
