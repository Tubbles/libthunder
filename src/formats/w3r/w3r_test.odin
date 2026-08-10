package w3r

// Synthetic-fixture tests: hand-built w3r byte streams, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_f32 :: proc(buffer: ^[dynamic]u8, value: f32) {
	test_append_u32(buffer, transmute(u32)value)
}

@(private)
test_append_region :: proc(
	buffer: ^[dynamic]u8,
	name: string,
	creation_number: u32,
	weather_id: string,
	ambient_sound: string,
) {
	test_append_f32(buffer, -1024)
	test_append_f32(buffer, -512)
	test_append_f32(buffer, 1024)
	test_append_f32(buffer, 512)
	append(buffer, name)
	append(buffer, 0)
	test_append_u32(buffer, creation_number)
	append(buffer, weather_id)
	append(buffer, ambient_sound)
	append(buffer, 0)
	append(buffer, 0x80, 0x40, 0x20, 0xFF)
}

@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_u32(&file, 5)
	test_append_u32(&file, 2)
	test_append_region(&file, "Snow Area", 7, "SNhs", "gg_snd_Blizzard")
	test_append_region(&file, "Plain", 8, "\x00\x00\x00\x00", "")
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	map_regions, error := parse(file[:])
	defer destroy(&map_regions)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_regions.version, i32(5))
	testing.expect_value(t, len(map_regions.regions), 2)
	testing.expect_value(t, map_regions.regions[0].left, f32(-1024))
	testing.expect_value(t, map_regions.regions[0].bottom, f32(-512))
	testing.expect_value(t, map_regions.regions[0].right, f32(1024))
	testing.expect_value(t, map_regions.regions[0].top, f32(512))
	testing.expect_value(t, map_regions.regions[0].name, "Snow Area")
	testing.expect_value(t, map_regions.regions[0].creation_number, i32(7))
	testing.expect_value(t, map_regions.regions[0].weather_id, [4]u8{'S', 'N', 'h', 's'})
	testing.expect_value(t, map_regions.regions[0].ambient_sound, "gg_snd_Blizzard")
	testing.expect_value(t, map_regions.regions[0].color_bgra, [4]u8{0x80, 0x40, 0x20, 0xFF})
	testing.expect(t, has_weather(map_regions.regions[0]), "weather id not reported")
	testing.expect_value(t, map_regions.regions[1].name, "Plain")
	testing.expect_value(t, map_regions.regions[1].creation_number, i32(8))
	testing.expect_value(t, map_regions.regions[1].ambient_sound, "")
	testing.expect(t, !has_weather(map_regions.regions[1]), "zero weather id reported as set")
}

// The 158 stock maps without regions ship exactly this file.
@(test)
empty_file_decodes :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 5)
	test_append_u32(&file, 0)

	map_regions, error := parse(file[:])
	defer destroy(&map_regions)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(map_regions.regions), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[0] = 4
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

// Every truncation of a good file must be refused, without leaking the
// regions and strings parsed before the cut.
@(test)
truncation_sweep_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 0 ..< len(file) {
		map_regions, error := parse(file[:length])
		defer destroy(&map_regions)
		testing.expect(t, error != .None, "truncated file accepted")
	}
}

@(test)
count_overrun_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	file[4] = 3
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// A count whose product with the 30-byte minimum record size wraps
// 32-bit arithmetic must not pass the check; the validation runs in
// i64, before the allocation.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 5)
	// 0x0888_8889 * 30 == 0x1_0000_000E, i.e. 14 in wrapped 32-bit
	// arithmetic, which is under the byte count that follows.
	test_append_u32(&file, 0x0888_8889)
	for _ in 0 ..< 64 {
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// Some protection tools write the rawcode "FUCK" where the region
// count belongs. No stock map does, and the count check refuses it
// without a dedicated special case.
@(test)
protection_signature_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 5)
	append(&file, "FUCK")
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

@(test)
unterminated_name_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 5)
	test_append_u32(&file, 1)
	test_append_f32(&file, -1024)
	test_append_f32(&file, -512)
	test_append_f32(&file, 1024)
	test_append_f32(&file, 512)
	append(&file, "Never ends")
	for _ in 0 ..< 24 {
		append(&file, 0x41)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unterminated_String)
}

@(test)
unterminated_ambient_sound_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 5)
	test_append_u32(&file, 1)
	test_append_region(&file, "Snow Area", 7, "SNhs", "gg_snd_Blizzard")
	// Drop the colour and overwrite the sound's terminator.
	for _ in 0 ..< 5 {
		pop(&file)
	}
	append(&file, 0x41)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unterminated_String)
}

@(test)
trailing_bytes_are_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	append(&file, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Trailing_Bytes)
}
