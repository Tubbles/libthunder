package imp

// Synthetic-fixture tests: hand-built imp byte streams, no game data.

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
test_append_entry :: proc(buffer: ^[dynamic]u8, flags: u8, path: string) {
	append(buffer, flags)
	append(buffer, path)
	append(buffer, 0)
}

// Three entries: one of each corpus-observed flags value, plus one
// carrying an unobserved value to show the raw byte is passed through.
@(private)
test_build_minimal_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 3)
	test_append_entry(&file, FLAGS_STANDARD_PATH, "BTNCustomIcon.blp")
	test_append_entry(&file, FLAGS_CUSTOM_PATH, "war3mapPreview.tga")
	test_append_entry(&file, 5, "")
	return file
}

@(test)
minimal_file_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_file()
	defer delete(file)

	imported_files, error := parse(file[:])
	defer destroy(&imported_files)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, imported_files.version, SUPPORTED_VERSION)
	testing.expect_value(t, len(imported_files.files), 3)
	testing.expect_value(t, imported_files.files[0].flags, FLAGS_STANDARD_PATH)
	testing.expect_value(t, imported_files.files[0].path, "BTNCustomIcon.blp")
	testing.expect_value(t, imported_files.files[1].flags, FLAGS_CUSTOM_PATH)
	testing.expect_value(t, imported_files.files[1].path, "war3mapPreview.tga")
	testing.expect_value(t, imported_files.files[2].flags, 5)
	testing.expect_value(t, imported_files.files[2].path, "")
}

@(test)
empty_file_decodes :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 0)

	imported_files, error := parse(file[:])
	defer destroy(&imported_files)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(imported_files.files), 0)
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	rejected_versions := [?]i32{0, 2, -1}
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
		imported_files, error := parse(file[:length])
		defer destroy(&imported_files)
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
	append(&file, FLAGS_STANDARD_PATH, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// 0x8000_0002 * 2 (the minimum bytes per entry) is 0x1_0000_0004,
// which wraps to 4 in 32-bit arithmetic and would pass a size check
// against the 4 remaining bytes. The validation runs in i64, so it
// does not.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_u32(&file, 0x8000_0002)
	append(&file, 0, 0, 0, 0)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// An entry whose path has no terminator before the end of the file.
@(test)
unterminated_string_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, SUPPORTED_VERSION)
	test_append_i32(&file, 1)
	append(&file, FLAGS_CUSTOM_PATH)
	append(&file, "war3mapPreview.tga")
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
