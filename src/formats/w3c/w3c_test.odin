package w3c

// Synthetic-fixture tests: hand-built w3c byte streams, no game data.

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
test_append_camera :: proc(buffer: ^[dynamic]u8, name: string, target_x: f32, rotation: f32) {
	test_append_f32(buffer, target_x)
	test_append_f32(buffer, -2048)
	test_append_f32(buffer, 0)
	test_append_f32(buffer, rotation)
	test_append_f32(buffer, 304)
	test_append_f32(buffer, 1650)
	test_append_f32(buffer, 0)
	test_append_f32(buffer, 70)
	test_append_f32(buffer, 5000)
	test_append_f32(buffer, 100)
	append(buffer, name)
	append(buffer, 0)
}

@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_u32(&file, 0)
	test_append_u32(&file, 2)
	test_append_camera(&file, "Intro", 1024, 90)
	test_append_camera(&file, "Outro", 512, 270)
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	map_cameras, error := parse(file[:])
	defer destroy(&map_cameras)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_cameras.version, i32(0))
	testing.expect_value(t, len(map_cameras.cameras), 2)
	testing.expect_value(t, map_cameras.cameras[0].name, "Intro")
	testing.expect_value(t, map_cameras.cameras[0].target_x, f32(1024))
	testing.expect_value(t, map_cameras.cameras[0].target_y, f32(-2048))
	testing.expect_value(t, map_cameras.cameras[0].z_offset, f32(0))
	testing.expect_value(t, map_cameras.cameras[0].rotation, f32(90))
	testing.expect_value(t, map_cameras.cameras[0].angle_of_attack, f32(304))
	testing.expect_value(t, map_cameras.cameras[0].distance, f32(1650))
	testing.expect_value(t, map_cameras.cameras[0].roll, f32(0))
	testing.expect_value(t, map_cameras.cameras[0].field_of_view, f32(70))
	testing.expect_value(t, map_cameras.cameras[0].far_clipping_plane, f32(5000))
	testing.expect_value(t, map_cameras.cameras[0].near_clipping_plane, f32(100))
	testing.expect_value(t, map_cameras.cameras[1].name, "Outro")
	testing.expect_value(t, map_cameras.cameras[1].rotation, f32(270))
}

// The 176 stock maps without cameras ship exactly this file.
@(test)
empty_file_decodes :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)

	map_cameras, error := parse(file[:])
	defer destroy(&map_cameras)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(map_cameras.cameras), 0)
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
// cameras parsed before the cut.
@(test)
truncation_sweep_is_rejected :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)
	for length in 0 ..< len(file) {
		map_cameras, error := parse(file[:length])
		defer destroy(&map_cameras)
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

// A count whose product with the 41-byte minimum record size wraps
// 32-bit arithmetic must not pass the check; the validation runs in
// i64, before the allocation.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	// 0x063E_7064 * 41 == 0x1_0000_0004, i.e. 4 in wrapped 32-bit
	// arithmetic, which is under the byte count that follows.
	test_append_u32(&file, 0x063E_7064)
	for _ in 0 ..< 64 {
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

@(test)
unterminated_name_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	test_append_u32(&file, 1)
	test_append_camera(&file, "Intro", 1024, 90)
	pop(&file)
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

// The Reforged camera shape appends three floats per record without
// bumping the version. Reading it as the classic ten-float shape
// derails: the first extra float's leading zero byte terminates the
// name early and every later field is misaligned, so the parse stops
// short of end-of-file.
@(test)
reforged_shape_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, 0)
	test_append_u32(&file, 2)
	for name in ([?]string{"Alpha", "Beta"}) {
		test_append_f32(&file, 1024)
		test_append_f32(&file, -2048)
		test_append_f32(&file, 0)
		test_append_f32(&file, 90)
		test_append_f32(&file, 304)
		test_append_f32(&file, 1650)
		test_append_f32(&file, 0)
		test_append_f32(&file, 70)
		test_append_f32(&file, 5000)
		test_append_f32(&file, 100)
		test_append_f32(&file, 5)
		test_append_f32(&file, 6)
		test_append_f32(&file, 7)
		append(&file, name)
		append(&file, 0)
	}
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Trailing_Data)
}
