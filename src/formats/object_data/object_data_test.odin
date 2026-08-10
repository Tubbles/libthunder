package object_data

// Synthetic-fixture tests: hand-built object-data byte streams for
// both shapes and both supported versions, no game data.

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

// One modification of each of the four value types. The leveled
// shape's fixtures write a level and data pointer per modification;
// end tokens exercise the corpus-observed spread (zero, the entry's
// old id, an unrelated rawcode).
@(private)
test_append_four_modifications :: proc(file: ^[dynamic]u8, shape: Shape) {
	append(file, "unam")
	test_append_i32(file, i32(Value_Type.String))
	if shape == .Leveled {
		test_append_i32(file, 0)
		test_append_i32(file, 0)
	}
	test_append_string(file, "Custom Name")
	test_append_u32(file, 0)

	append(file, "uhpm")
	test_append_i32(file, i32(Value_Type.Integer))
	if shape == .Leveled {
		test_append_i32(file, 2)
		test_append_i32(file, 1)
	}
	test_append_i32(file, 500)
	append(file, "hfoo")

	append(file, "umvs")
	test_append_i32(file, i32(Value_Type.Real))
	if shape == .Leveled {
		test_append_i32(file, 3)
		test_append_i32(file, 6)
	}
	test_append_f32(file, 270.5)
	test_append_u32(file, 0)

	append(file, "uabr")
	test_append_i32(file, i32(Value_Type.Unreal))
	if shape == .Leveled {
		test_append_i32(file, 15)
		test_append_i32(file, 4)
	}
	test_append_f32(file, 0.25)
	append(file, "zzzz")
}

// An original table with one entry of four modifications and a custom
// table with two entries (four modifications and none).
@(private)
test_build_file :: proc(version: i32, shape: Shape) -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_i32(&file, version)

	test_append_u32(&file, 1)
	append(&file, "hfoo")
	test_append_u32(&file, 0)
	test_append_u32(&file, 4)
	test_append_four_modifications(&file, shape)

	test_append_u32(&file, 2)
	append(&file, "hfoo")
	append(&file, "h000")
	test_append_u32(&file, 4)
	test_append_four_modifications(&file, shape)
	append(&file, "hpea")
	append(&file, "h001")
	test_append_u32(&file, 0)
	return file
}

@(private)
test_expect_four_modifications :: proc(t: ^testing.T, modifications: []Modification, shape: Shape, old_id: [4]u8) {
	testing.expect_value(t, len(modifications), 4)
	if len(modifications) != 4 {
		return
	}
	testing.expect_value(t, modifications[0].id, [4]u8{'u', 'n', 'a', 'm'})
	testing.expect_value(t, modifications[0].value_type, Value_Type.String)
	testing.expect_value(t, modifications[0].value.(string), "Custom Name")
	testing.expect_value(t, modifications[0].end_token, [4]u8{})

	testing.expect_value(t, modifications[1].id, [4]u8{'u', 'h', 'p', 'm'})
	testing.expect_value(t, modifications[1].value_type, Value_Type.Integer)
	testing.expect_value(t, modifications[1].value.(i32), 500)
	testing.expect_value(t, modifications[1].end_token, old_id)

	testing.expect_value(t, modifications[2].id, [4]u8{'u', 'm', 'v', 's'})
	testing.expect_value(t, modifications[2].value_type, Value_Type.Real)
	testing.expect_value(t, modifications[2].value.(f32), 270.5)

	testing.expect_value(t, modifications[3].id, [4]u8{'u', 'a', 'b', 'r'})
	testing.expect_value(t, modifications[3].value_type, Value_Type.Unreal)
	testing.expect_value(t, modifications[3].value.(f32), 0.25)
	testing.expect_value(t, modifications[3].end_token, [4]u8{'z', 'z', 'z', 'z'})

	if shape == .Leveled {
		testing.expect_value(t, modifications[1].level, 2)
		testing.expect_value(t, modifications[1].data_pointer, 1)
		testing.expect_value(t, modifications[2].level, 3)
		testing.expect_value(t, modifications[2].data_pointer, 6)
		testing.expect_value(t, modifications[3].level, 15)
		testing.expect_value(t, modifications[3].data_pointer, 4)
	} else {
		testing.expect_value(t, modifications[1].level, 0)
		testing.expect_value(t, modifications[1].data_pointer, 0)
	}
}

@(private)
test_expect_fixture :: proc(t: ^testing.T, object_data: ^Object_Data, version: i32, shape: Shape) {
	testing.expect_value(t, object_data.version, version)
	testing.expect_value(t, object_data.shape, shape)

	testing.expect_value(t, len(object_data.original), 1)
	original := object_data.original[0]
	testing.expect_value(t, original.old_id, [4]u8{'h', 'f', 'o', 'o'})
	testing.expect_value(t, original.new_id, [4]u8{})
	test_expect_four_modifications(t, original.modifications, shape, original.old_id)

	testing.expect_value(t, len(object_data.custom), 2)
	custom := object_data.custom[0]
	testing.expect_value(t, custom.old_id, [4]u8{'h', 'f', 'o', 'o'})
	testing.expect_value(t, custom.new_id, [4]u8{'h', '0', '0', '0'})
	test_expect_four_modifications(t, custom.modifications, shape, custom.old_id)
	testing.expect_value(t, object_data.custom[1].old_id, [4]u8{'h', 'p', 'e', 'a'})
	testing.expect_value(t, object_data.custom[1].new_id, [4]u8{'h', '0', '0', '1'})
	testing.expect_value(t, len(object_data.custom[1].modifications), 0)
}

@(test)
simple_shape_both_versions_decode :: proc(t: ^testing.T) {
	for version in i32(MINIMUM_VERSION) ..= i32(MAXIMUM_VERSION) {
		file := test_build_file(version, .Simple)
		defer delete(file)
		object_data, error := parse(file[:], .Simple)
		defer destroy(&object_data)
		testing.expect_value(t, error, Error.None)
		test_expect_fixture(t, &object_data, version, .Simple)
	}
}

@(test)
leveled_shape_both_versions_decode :: proc(t: ^testing.T) {
	for version in i32(MINIMUM_VERSION) ..= i32(MAXIMUM_VERSION) {
		file := test_build_file(version, .Leveled)
		defer delete(file)
		object_data, error := parse(file[:], .Leveled)
		defer destroy(&object_data)
		testing.expect_value(t, error, Error.None)
		test_expect_fixture(t, &object_data, version, .Leveled)
	}
}

@(test)
empty_tables_decode :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	object_data, error := parse(file[:], .Simple)
	defer destroy(&object_data)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(object_data.original), 0)
	testing.expect_value(t, len(object_data.custom), 0)
}

@(test)
shape_for_extension_maps_all_seven :: proc(t: ^testing.T) {
	simple_extensions := [?]string{"w3u", "w3t", "w3b", "w3h"}
	for extension in simple_extensions {
		shape, known := shape_for_extension(extension)
		testing.expect_value(t, known, true)
		testing.expect_value(t, shape, Shape.Simple)
	}
	leveled_extensions := [?]string{"w3a", "w3q", "w3d"}
	for extension in leveled_extensions {
		shape, known := shape_for_extension(extension)
		testing.expect_value(t, known, true)
		testing.expect_value(t, shape, Shape.Leveled)
	}
	_, known := shape_for_extension("w3i")
	testing.expect_value(t, known, false)
}

@(test)
wrong_shape_usually_errors :: proc(t: ^testing.T) {
	// The common mismatch direction: a leveled file parsed as Simple
	// misreads level bytes as a value and derails into an error. Not
	// guaranteed by the format (see the parse doc comment), but true
	// of this fixture and of 58 of the 61 corpus files.
	file := test_build_file(2, .Leveled)
	defer delete(file)
	object_data, error := parse(file[:], .Simple)
	testing.expect(t, error != .None, "expected the shape mismatch to error")
	testing.expect_value(t, len(object_data.original), 0)
}

@(test)
wrong_shape_realignment_is_not_detected :: proc(t: ^testing.T) {
	// The format has no in-band shape marker (see the parse doc
	// comment): a simple-shape file whose modifications are all
	// strings of 8 or more characters parses as Leveled, silently
	// consuming each string's first 8 bytes as level/data_pointer.
	// Three corpus files exhibit this. The test pins the documented
	// limitation so a change in behavior is noticed.
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 1)
	append(&file, "hfoo")
	test_append_u32(&file, 0)
	test_append_u32(&file, 1)
	append(&file, "unam")
	test_append_i32(&file, i32(Value_Type.String))
	test_append_string(&file, "TRIGSTR_197")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)

	object_data, error := parse(file[:], .Leveled)
	defer destroy(&object_data)
	testing.expect_value(t, error, Error.None)
	value, is_string := object_data.original[0].modifications[0].value.(string)
	testing.expect(t, is_string)
	testing.expect_value(t, value, "197")
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_file(3, .Simple)
	defer delete(file)
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Unsupported_Version)
	file[0] = 0
	_, zero_error := parse(file[:], .Simple)
	testing.expect_value(t, zero_error, Error.Unsupported_Version)
	empty: []u8
	_, empty_error := parse(empty, .Simple)
	testing.expect_value(t, empty_error, Error.Truncated)
}

// Every strict prefix of a full fixture must produce an error, never
// a crash or a leak (the test runner tracks memory): the two tables
// are count-prefixed and the parse requires exact end-of-file, so no
// truncation point yields a valid shorter file.
@(test)
all_truncations_error_cleanly :: proc(t: ^testing.T) {
	shapes := [?]Shape{.Simple, .Leveled}
	for shape in shapes {
		file := test_build_file(2, shape)
		defer delete(file)
		for length in 0 ..< len(file) {
			_, error := parse(file[:length], shape)
			testing.expect(t, error != .None, "truncated prefix parsed cleanly")
		}
	}
}

// A table count far larger than the remaining bytes must fail before
// the allocation.
@(test)
oversized_entry_count_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 0x7FFF_FFFF)
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Invalid_Count)
}

// A count whose product with the element size wraps a 32-bit int but
// not the i64 the validation runs in: 0x2000_0000 entries at 12 bytes
// minimum is 0x1_8000_0000, far beyond the file, and must be rejected
// even though the low 32 bits of the product are small.
@(test)
count_product_wrap_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 0x2000_0000)
	for _ in 0 ..< 64 {
		append(&file, 0)
	}
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Invalid_Count)
}

// A modification count is validated the same way, inside an entry.
@(test)
oversized_modification_count_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 1)
	append(&file, "hfoo")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0x7FFF_FFFF)
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Invalid_Count)
}

@(test)
unknown_value_type_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 1)
	append(&file, "hfoo")
	test_append_u32(&file, 0)
	test_append_u32(&file, 1)
	append(&file, "unam")
	test_append_i32(&file, 4)
	test_append_i32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Unknown_Value_Type)
	// A negative tag is equally unknown (patch the tag's high byte;
	// the tag sits 13 bytes before the end: tag, value, end token,
	// and the empty custom table's count).
	file[len(file) - 13] = 0xFF
	_, negative_error := parse(file[:], .Simple)
	testing.expect_value(t, negative_error, Error.Unknown_Value_Type)
}

// A string value running to the end of the buffer without a NUL.
@(test)
unterminated_string_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_i32(&file, 2)
	test_append_u32(&file, 1)
	append(&file, "hfoo")
	test_append_u32(&file, 0)
	test_append_u32(&file, 1)
	append(&file, "unam")
	test_append_i32(&file, i32(Value_Type.String))
	append(&file, "An Unterminated Value")
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Unterminated_String)
}

// Leftover bytes after the custom table are corrupt (every corpus
// file ends exactly at the end of the custom table).
@(test)
trailing_bytes_are_rejected :: proc(t: ^testing.T) {
	file := test_build_file(2, .Simple)
	defer delete(file)
	append(&file, 0)
	_, error := parse(file[:], .Simple)
	testing.expect_value(t, error, Error.Trailing_Bytes)
}
