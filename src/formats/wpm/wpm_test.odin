package wpm

// Synthetic-fixture tests: hand-built wpm byte streams, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	append(&file, "MP3W")
	test_append_u32(&file, 0)
	test_append_u32(&file, 4)
	test_append_u32(&file, 2)
	append(
		&file,
		CELL_NO_WALK | CELL_NO_FLY | CELL_NO_BUILD,
		CELL_NO_WATER,
		CELL_BLIGHT | CELL_NO_WATER,
		0x00,
		CELL_UNKNOWN_0X80,
		CELL_NO_WATER,
		CELL_NO_WATER,
		CELL_NO_WALK,
	)
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	pathing_map, error := parse(file[:])
	defer destroy(&pathing_map)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, pathing_map.width, 4)
	testing.expect_value(t, pathing_map.height, 2)
	testing.expect_value(t, len(pathing_map.cells), 8)
	testing.expect_value(t, cell(&pathing_map, 0, 0), CELL_NO_WALK | CELL_NO_FLY | CELL_NO_BUILD)
	testing.expect_value(t, cell(&pathing_map, 2, 0), CELL_BLIGHT | CELL_NO_WATER)
	testing.expect_value(t, cell(&pathing_map, 0, 1), CELL_UNKNOWN_0X80)
	testing.expect_value(t, cell(&pathing_map, 3, 1), CELL_NO_WALK)
	testing.expect_value(t, cell(&pathing_map, 4, 0), 0)
	testing.expect_value(t, cell(&pathing_map, 0, -1), 0)
}

@(test)
bad_magic_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[3] = '?'
	pathing_map, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Magic)
	testing.expect_value(t, len(pathing_map.cells), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[4] = 1
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

@(test)
truncated_header_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 4 ..< 16 {
		_, error := parse(file[:length])
		testing.expect_value(t, error, Error.Truncated_Header)
	}
}

@(test)
cell_count_mismatch_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	_, error := parse(file[:len(file) - 1])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
}

// A dimension pair whose product wraps 32-bit arithmetic to exactly
// the remaining byte count (0x80000004 * 2 wraps to 8) must not pass
// the size check; the validation runs in i64.
@(test)
zero_dimension_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MP3W")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 7)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
}

@(test)
dimension_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MP3W")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0x8000_0004)
	test_append_u32(&file, 2)
	append(&file, 0, 0, 0, 0, 0, 0, 0, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Dimensions)
}
