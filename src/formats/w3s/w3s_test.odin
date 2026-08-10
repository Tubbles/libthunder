package w3s

// Synthetic-fixture tests: hand-built w3s byte streams, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_i32 :: proc(buffer: ^[dynamic]u8, value: i32) {
	test_append_u32(buffer, u32(value))
}

@(private)
test_append_f32 :: proc(buffer: ^[dynamic]u8, value: f32) {
	test_append_u32(buffer, transmute(u32)value)
}

@(private)
test_append_string :: proc(buffer: ^[dynamic]u8, text: string) {
	append(buffer, text)
	append(buffer, 0)
}

// Two sounds: a fully specified 3D looping ambience and a second one
// left entirely at its SLK defaults (empty strings, every sentinel).
@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 2)

	test_append_string(&file, "gg_snd_Rain")
	test_append_string(&file, "Sound\\Ambient\\Rain.wav")
	test_append_string(&file, "DefaultEAXON")
	test_append_u32(&file, FLAG_LOOPING | FLAG_3D_SOUND)
	test_append_i32(&file, 10)
	test_append_i32(&file, 12)
	test_append_i32(&file, 127)
	test_append_f32(&file, 1.5)
	test_append_f32(&file, 0.25)
	test_append_i32(&file, 20)
	test_append_i32(&file, CHANNEL_LOOPING_AMBIENT)
	test_append_f32(&file, 600.0)
	test_append_f32(&file, 8000.0)
	test_append_f32(&file, 3000.0)
	test_append_f32(&file, 90.0)
	test_append_f32(&file, 180.0)
	test_append_i32(&file, 64)
	test_append_f32(&file, 1.0)
	test_append_f32(&file, 2.0)
	test_append_f32(&file, 3.0)

	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_u32(&file, 0)
	test_append_i32(&file, 0)
	test_append_i32(&file, 0)
	test_append_i32(&file, UNSET_INTEGER)
	test_append_f32(&file, UNSET_FLOAT)
	test_append_f32(&file, UNSET_FLOAT)
	test_append_i32(&file, UNSET_INTEGER)
	test_append_i32(&file, UNSET_INTEGER)
	for _ in 0 ..< 5 {
		test_append_f32(&file, UNSET_FLOAT)
	}
	test_append_i32(&file, UNSET_INTEGER)
	for _ in 0 ..< 3 {
		test_append_f32(&file, UNSET_FLOAT)
	}
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	map_sounds, error := parse(file[:])
	defer destroy(&map_sounds)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_sounds.version, SUPPORTED_VERSION)
	testing.expect_value(t, len(map_sounds.sounds), 2)

	first := map_sounds.sounds[0]
	testing.expect_value(t, first.name, "gg_snd_Rain")
	testing.expect_value(t, first.file_path, "Sound\\Ambient\\Rain.wav")
	testing.expect_value(t, first.eax_setting, "DefaultEAXON")
	testing.expect_value(t, first.flags, FLAG_LOOPING | FLAG_3D_SOUND)
	testing.expect_value(t, first.fade_in_rate, 10)
	testing.expect_value(t, first.fade_out_rate, 12)
	testing.expect_value(t, first.volume, 127)
	testing.expect_value(t, first.pitch, 1.5)
	testing.expect_value(t, first.pitch_variance, 0.25)
	testing.expect_value(t, first.priority, 20)
	testing.expect_value(t, first.channel, CHANNEL_LOOPING_AMBIENT)
	testing.expect_value(t, first.minimum_distance, 600.0)
	testing.expect_value(t, first.maximum_distance, 8000.0)
	testing.expect_value(t, first.distance_cutoff, 3000.0)
	testing.expect_value(t, first.cone_angle_inside, 90.0)
	testing.expect_value(t, first.cone_angle_outside, 180.0)
	testing.expect_value(t, first.cone_outside_volume, 64)
	testing.expect_value(t, first.cone_orientation, [3]f32{1.0, 2.0, 3.0})

	second := map_sounds.sounds[1]
	testing.expect_value(t, second.name, "")
	testing.expect_value(t, second.file_path, "")
	testing.expect_value(t, second.eax_setting, "")
	testing.expect_value(t, second.flags, 0)
	testing.expect_value(t, second.volume, UNSET_INTEGER)
	testing.expect_value(t, second.channel, UNSET_INTEGER)
	testing.expect_value(t, second.cone_outside_volume, UNSET_INTEGER)
	testing.expect_value(t, second.pitch, UNSET_FLOAT)
	testing.expect_value(t, second.cone_orientation, [3]f32{UNSET_FLOAT, UNSET_FLOAT, UNSET_FLOAT})
}

@(test)
empty_file_decodes :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 0)

	map_sounds, error := parse(file[:])
	defer destroy(&map_sounds)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(map_sounds.sounds), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	rejected_versions := [?]i32{0, 2, 3, -1}
	for version in rejected_versions {
		file := test_build_minimal_file()
		defer delete(file)
		unsupported := transmute([4]u8)version
		copy(file[:4], unsupported[:])
		_, error := parse(file[:])
		testing.expect_value(t, error, Error.Unsupported_Version)
	}
}

// Every truncation of a valid file must be rejected cleanly. The test
// runner's leak tracking covers the partial-parse cleanup paths.
@(test)
truncated_file_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 0 ..< len(file) {
		map_sounds, error := parse(file[:length])
		defer destroy(&map_sounds)
		testing.expectf(t, error != .None, "truncation to %d bytes was accepted", length)
	}
}

// A declared count larger than the remaining bytes can hold must be
// rejected before the slice is allocated.
@(test)
count_overrun_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_u32(&file, 0xFFFF_FFFF)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// 60492498 * 71 (the minimum bytes per sound) is 0x1_0000_003E, which
// wraps to 62 in 32-bit arithmetic and would pass a size check against
// the 62 remaining bytes. The validation runs in i64, so it does not.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_u32(&file, 60492498)
	for _ in 0 ..< 62 {
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// A record whose EAX string has no terminator anywhere before the end
// of the file: the count check passes (73 bytes remain, more than the
// 71 a sound needs at minimum) but the string runs off the end. Freeing
// the two strings already parsed out of the record is the leak path
// this covers.
@(test)
unterminated_string_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 1)
	test_append_string(&file, "gg_snd_Unterminated")
	test_append_string(&file, "Sound\\Ambient\\Rain.wav")
	for _ in 0 ..< 30 {
		append(&file, 'A')
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unterminated_String)
}

@(test)
trailing_bytes_are_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	append(&file, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Trailing_Data)
}
