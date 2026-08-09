package mdx

// Bounds-checked little-endian byte reading. Nested structures (chunks,
// sized items, node track regions) parse through a sub-reader whose data
// slice is truncated to the region end, so every read inside a region is
// automatically bounded by it.

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
read_tag :: proc(reader: ^Reader) -> (tag: [4]u8, ok: bool) {
	if reader_remaining(reader) < 4 {
		return {}, false
	}
	copy(tag[:], reader.data[reader.offset:reader.offset + 4])
	reader.offset += 4
	return tag, true
}

@(private)
peek_tag_matches :: proc(reader: ^Reader, expected: string) -> bool {
	if reader_remaining(reader) < 4 {
		return false
	}
	return string(reader.data[reader.offset:reader.offset + 4]) == expected
}

@(private)
expect_tag :: proc(reader: ^Reader, expected: string) -> bool {
	tag, ok := read_tag(reader)
	return ok && string(tag[:]) == expected
}

// Reads one little-endian value: a 1/2/4-byte scalar or a fixed array
// of such values (element order as stored).
@(private)
read_value :: proc(reader: ^Reader, value: ^$Value) -> bool {
	when Value == u8 {
		if reader_remaining(reader) < 1 {
			return false
		}
		value^ = reader.data[reader.offset]
		reader.offset += 1
		return true
	} else when Value == u16 {
		if reader_remaining(reader) < 2 {
			return false
		}
		data := reader.data[reader.offset:]
		value^ = u16(data[0]) | u16(data[1]) << 8
		reader.offset += 2
		return true
	} else when Value == u32 {
		raw := read_u32(reader) or_return
		value^ = raw
		return true
	} else when Value == i32 {
		raw := read_u32(reader) or_return
		value^ = transmute(i32)raw
		return true
	} else when Value == f32 {
		raw := read_u32(reader) or_return
		value^ = transmute(f32)raw
		return true
	} else {
		for index in 0 ..< len(value) {
			read_value(reader, &value[index]) or_return
		}
		return true
	}
}

@(private)
read_extent :: proc(reader: ^Reader, extent: ^Extent) -> bool {
	return read_value(reader, &extent.bounds_radius) &&
		read_value(reader, &extent.minimum_extent) &&
		read_value(reader, &extent.maximum_extent)
}

// Reads a fixed-length NUL-padded string field and clones the content
// up to the first NUL (or the whole field when no NUL is present).
@(private)
read_fixed_string :: proc(reader: ^Reader, length: int, allocator: runtime.Allocator) -> (text: string, error: Error) {
	if reader_remaining(reader) < length {
		return "", .Corrupt_Chunk
	}
	raw := reader.data[reader.offset:reader.offset + length]
	reader.offset += length
	terminator := 0
	for terminator < length && raw[terminator] != 0 {
		terminator += 1
	}
	return strings.clone(string(raw[:terminator]), allocator), .None
}

// Validates a count field against the remaining region bytes, then
// allocates and reads the elements. Validation happens before the
// allocation so malformed counts cannot trigger huge allocations.
@(private)
read_array :: proc(reader: ^Reader, count: u32, list: ^[]$Element, allocator: runtime.Allocator) -> Error {
	if int(count) * size_of(Element) > reader_remaining(reader) {
		return .Corrupt_Chunk
	}
	list^ = make([]Element, int(count), allocator)
	for index in 0 ..< len(list^) {
		if !read_value(reader, &list^[index]) {
			return .Corrupt_Chunk
		}
	}
	return .None
}

// Reads a tagged, counted array: 4-byte tag, u32 element count, then
// the elements (the geoset sub-chunk layout).
@(private)
read_counted_array :: proc(reader: ^Reader, expected_tag: string, list: ^[]$Element, allocator: runtime.Allocator) -> Error {
	if !expect_tag(reader, expected_tag) {
		return .Corrupt_Chunk
	}
	count, count_ok := read_u32(reader)
	if !count_ok {
		return .Corrupt_Chunk
	}
	return read_array(reader, count, list, allocator)
}

// Consumes the u32 inclusive size of an item and returns a sub-reader
// bounded to the item, plus the absolute item end for advancing the
// outer reader once the item parsed successfully.
@(private)
begin_sized_item :: proc(reader: ^Reader, minimum_size: u32) -> (sub: Reader, item_end: int, ok: bool) {
	item_start := reader.offset
	inclusive_size, size_ok := read_u32(reader)
	if !size_ok || inclusive_size < minimum_size {
		return {}, 0, false
	}
	item_end = item_start + int(inclusive_size)
	if item_end > len(reader.data) {
		return {}, 0, false
	}
	sub = Reader {
		data   = reader.data[:item_end],
		offset = reader.offset,
	}
	return sub, item_end, true
}
