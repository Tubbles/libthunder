package object_data

// Bounds-checked little-endian reading plus the shape-parameterized
// parse. Validation arithmetic on file-supplied counts runs in i64,
// before any allocation, so a 32-bit int target cannot wrap a product
// into a passing check (same approach as thunder:formats/w3i and
// thunder:formats/mdx).

import "base:runtime"
import "core:strings"

@(private)
Reader :: struct {
	data:   []u8,
	offset: int,
}

@(private)
reader_remaining :: proc(reader: ^Reader) -> int {
	return len(reader.data) - reader.offset
}

@(private)
read_u32 :: proc(reader: ^Reader) -> (value: u32, ok: bool) {
	if reader_remaining(reader) < 4 {
		return 0, false
	}
	data := reader.data[reader.offset:]
	value = u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16 | u32(data[3]) << 24
	reader.offset += 4
	return value, true
}

@(private)
read_i32 :: proc(reader: ^Reader) -> (value: i32, ok: bool) {
	raw := read_u32(reader) or_return
	return i32(raw), true
}

@(private)
read_f32 :: proc(reader: ^Reader) -> (value: f32, ok: bool) {
	raw := read_u32(reader) or_return
	return transmute(f32)raw, true
}

@(private)
read_bytes :: proc(reader: ^Reader, buffer: []u8) -> bool {
	if reader_remaining(reader) < len(buffer) {
		return false
	}
	copy(buffer, reader.data[reader.offset:])
	reader.offset += len(buffer)
	return true
}

// Reads a NUL-terminated string and clones the content without the
// terminator. A string running to the end of the data is corrupt.
@(private)
read_string :: proc(reader: ^Reader, allocator: runtime.Allocator) -> (text: string, error: Error) {
	terminator := reader.offset
	for terminator < len(reader.data) && reader.data[terminator] != 0 {
		terminator += 1
	}
	if terminator == len(reader.data) {
		return "", .Unterminated_String
	}
	text = strings.clone(string(reader.data[reader.offset:terminator]), allocator)
	reader.offset = terminator + 1
	return text, .None
}

// Reads a list count and validates it against the remaining bytes at
// the given minimum bytes per element, before the caller allocates.
@(private)
read_count :: proc(reader: ^Reader, minimum_element_size: i64) -> (count: int, error: Error) {
	raw, ok := read_u32(reader)
	if !ok {
		return 0, .Truncated
	}
	if i64(raw) * minimum_element_size > i64(reader_remaining(reader)) {
		return 0, .Invalid_Count
	}
	return int(raw), .None
}

// An entry is at minimum the two ids plus a modification count.
@(private)
ENTRY_MINIMUM_SIZE :: 12
// A modification is at minimum the id, the value-type tag, a one-byte
// empty string value, and the end token; the leveled shape adds the
// level and data-pointer fields.
@(private)
MODIFICATION_MINIMUM_SIZE_SIMPLE :: 13
@(private)
MODIFICATION_MINIMUM_SIZE_LEVELED :: 21

// Parses a complete object-data file of the given shape (see
// shape_for_extension). The whole input must be consumed: no corpus
// file carries trailing bytes (WI-0011 probe, exact end-of-file on
// all 61 files), so leftover input is corrupt. On error the partially
// built structure is freed and a zero value is returned.
//
// The format has no in-band shape marker, so a wrong shape argument
// is not reliably detected: most mismatches error (58 of the 61
// corpus files parsed with the opposite shape do), but a simple-shape
// file whose modifications are all strings of 8 or more characters
// parses as Leveled with the string's first 8 bytes consumed as
// level/data_pointer (3 corpus files exhibit this). Callers must take
// the shape from the file's extension, not guess it.
parse :: proc(data: []u8, shape: Shape, allocator := context.allocator) -> (object_data: Object_Data, error: Error) {
	building: Object_Data
	building.allocator = allocator
	building.shape = shape
	defer if error != .None {
		destroy(&building)
	}

	reader := Reader {
		data = data,
	}
	version, version_ok := read_i32(&reader)
	if !version_ok {
		return {}, .Truncated
	}
	if version < MINIMUM_VERSION || version > MAXIMUM_VERSION {
		return {}, .Unsupported_Version
	}
	building.version = version

	parse_table(&reader, &building.original, shape, allocator) or_return
	parse_table(&reader, &building.custom, shape, allocator) or_return
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Bytes
	}
	return building, .None
}

@(private)
parse_table :: proc(
	reader: ^Reader,
	table: ^[]Entry,
	shape: Shape,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	count := read_count(reader, ENTRY_MINIMUM_SIZE) or_return
	table^ = make([]Entry, count, allocator)
	for &entry in table^ {
		parse_entry(reader, &entry, shape, allocator) or_return
	}
	return .None
}

@(private)
parse_entry :: proc(
	reader: ^Reader,
	entry: ^Entry,
	shape: Shape,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	if !read_bytes(reader, entry.old_id[:]) || !read_bytes(reader, entry.new_id[:]) {
		return .Truncated
	}
	minimum_size: i64 = MODIFICATION_MINIMUM_SIZE_SIMPLE
	if shape == .Leveled {
		minimum_size = MODIFICATION_MINIMUM_SIZE_LEVELED
	}
	count := read_count(reader, minimum_size) or_return
	entry.modifications = make([]Modification, count, allocator)
	for &modification in entry.modifications {
		parse_modification(reader, &modification, shape, allocator) or_return
	}
	return .None
}

@(private)
parse_modification :: proc(
	reader: ^Reader,
	modification: ^Modification,
	shape: Shape,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	if !read_bytes(reader, modification.id[:]) {
		return .Truncated
	}
	raw_type, type_ok := read_i32(reader)
	if !type_ok {
		return .Truncated
	}
	if raw_type < i32(Value_Type.Integer) || raw_type > i32(Value_Type.String) {
		return .Unknown_Value_Type
	}
	modification.value_type = Value_Type(raw_type)

	if shape == .Leveled {
		level, level_ok := read_i32(reader)
		data_pointer, data_pointer_ok := read_i32(reader)
		if !level_ok || !data_pointer_ok {
			return .Truncated
		}
		modification.level = level
		modification.data_pointer = data_pointer
	}

	switch modification.value_type {
	case .Integer:
		value, value_ok := read_i32(reader)
		if !value_ok {
			return .Truncated
		}
		modification.value = value
	case .Real, .Unreal:
		value, value_ok := read_f32(reader)
		if !value_ok {
			return .Truncated
		}
		modification.value = value
	case .String:
		modification.value = read_string(reader, allocator) or_return
	}

	if !read_bytes(reader, modification.end_token[:]) {
		return .Truncated
	}
	return .None
}
