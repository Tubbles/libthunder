package mmp

// Synthetic-fixture tests: hand-built mmp byte streams, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_icon :: proc(buffer: ^[dynamic]u8, type: i32, x: i32, y: i32, color_bgra: [4]u8) {
	colors := color_bgra
	test_append_u32(buffer, u32(type))
	test_append_u32(buffer, u32(x))
	test_append_u32(buffer, u32(y))
	append(buffer, ..colors[:])
}

@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_u32(&file, 0)
	test_append_u32(&file, 3)
	test_append_icon(&file, ICON_TYPE_GOLD_MINE, 24, 21, {0xFF, 0xFF, 0xFF, 0xFF})
	test_append_icon(&file, ICON_TYPE_NEUTRAL_BUILDING, 128, 137, {0xFF, 0xFF, 0xFF, 0xFF})
	// Player 1 red, 0xFF0303, stored blue first.
	test_append_icon(&file, ICON_TYPE_PLAYER_START_LOCATION, 220, -6, {0x03, 0x03, 0xFF, 0xFF})
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	preview_icons, error := parse(file[:])
	defer destroy(&preview_icons)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, preview_icons.version, i32(0))
	testing.expect_value(t, len(preview_icons.icons), 3)
	testing.expect_value(t, preview_icons.icons[0].type, i32(ICON_TYPE_GOLD_MINE))
	testing.expect_value(t, preview_icons.icons[0].x, i32(24))
	testing.expect_value(t, preview_icons.icons[0].y, i32(21))
	testing.expect_value(t, preview_icons.icons[0].color_bgra, [4]u8{0xFF, 0xFF, 0xFF, 0xFF})
	testing.expect_value(t, preview_icons.icons[1].type, i32(ICON_TYPE_NEUTRAL_BUILDING))
	testing.expect_value(t, preview_icons.icons[2].type, i32(ICON_TYPE_PLAYER_START_LOCATION))
	testing.expect_value(t, preview_icons.icons[2].x, i32(220))
	// Negative coordinates occur in the stock corpus.
	testing.expect_value(t, preview_icons.icons[2].y, i32(-6))
	testing.expect_value(t, preview_icons.icons[2].color_bgra, [4]u8{0x03, 0x03, 0xFF, 0xFF})
}

@(test)
empty_file_decodes :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)

	preview_icons, error := parse(file[:])
	defer destroy(&preview_icons)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(preview_icons.icons), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[0] = 1
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

// Every truncation of a good file must be refused, without leaking the
// icons parsed before the cut.
@(test)
truncation_sweep_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 0 ..< len(file) {
		preview_icons, error := parse(file[:length])
		defer destroy(&preview_icons)
		testing.expect(t, error != .None, "truncated file accepted")
	}
}

@(test)
count_overrun_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[4] = 4
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// A count whose product with the 16-byte record size wraps 32-bit
// arithmetic must not pass the check; the validation runs in i64,
// before the allocation.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	// 0x1000_0000 * 16 == 0x1_0000_0000, i.e. zero in wrapped 32-bit
	// arithmetic.
	test_append_u32(&file, 0x1000_0000)
	for _ in 0 ..< 64 {
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

@(test)
trailing_bytes_are_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	append(&file, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Trailing_Bytes)
}
