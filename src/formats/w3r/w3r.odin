package w3r

// Reader for war3map.w3r, the named rectangular regions a map's
// triggers refer to. The file has no magic: an int32 version, an int32
// region count, then that many region records. Every one of the 186
// stock 1.29.2 maps declares version 5 (WI-0010 survey), the newest
// version and the only one this reader accepts.
//
// Per region, in file order:
//     f32 left, f32 bottom, f32 right, f32 top   (world units)
//     NUL-terminated name
//     i32 creation number
//     u8[4] weather effect id                    (all zero = none)
//     NUL-terminated ambient sound name          (a w3s gg_snd_ handle)
//     u8[4] display colour, blue green red alpha
// Field list and order from War3Net's Region reader (MIT, license
// verified; docs/research/file-formats.md) and independently from the
// HiveWE wiki page for this format, which agree field for field,
// including the colour's "BB GG RR AA" byte order. The colour is
// editor chrome, not gameplay data.
//
// Corpus-resolved: the fourth colour byte is 255 in all 1668 regions
// of the stock corpus, consistent with War3Net reading it as alpha.
// The weather id is all-zero in 1616 of those regions; the rest carry
// four-character codes such as "SNhs" and "RAlr".
//
// Older versions are rejected rather than guessed at. Per the HiveWE
// wiki the format grew incrementally (v1 integer bounds, v2 float
// bounds, v3 added the weather id, v4 the ambient sound, v5 the
// colour), and no v1-v4 file exists in the corpus to test against.
// This is also where the most complete available reference reader has
// a known gap: War3Net reads every field unconditionally even when its
// own version enum accepted an older value, so it would mis-read a
// genuinely short file.
//
// Map-protection signature: some protection tools write the rawcode
// "FUCK" where the region count belongs (War3Net checks for it by
// name). No stock map does. Strict parsing rejects it without a
// special case: read as a count that is roughly 1.2 billion regions,
// it fails the pre-allocation size check.

import "base:runtime"
import "core:strings"

Error :: enum {
	None,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Unterminated_String,
	Trailing_Data,
}

SUPPORTED_VERSION :: 5

Region :: struct {
	// World-unit bounds; left/bottom are the minimum corner.
	left:            f32,
	bottom:          f32,
	right:           f32,
	top:             f32,
	name:            string,
	// Editor-assigned identity, unique within the map but not an index
	// into this list.
	creation_number: i32,
	// Four-character weather effect code, all zero when the region has
	// no weather.
	weather_id:      [4]u8,
	// Name of a war3map.w3s sound (a "gg_snd_" handle), empty when the
	// region plays no ambient sound.
	ambient_sound:   string,
	// Editor display colour in file order: blue, green, red, alpha.
	color_bgra:      [4]u8,
}

Map_Regions :: struct {
	version:   i32,
	regions:   []Region,
	allocator: runtime.Allocator,
}

destroy :: proc(map_regions: ^Map_Regions) {
	for region in map_regions.regions {
		delete(region.name, map_regions.allocator)
		delete(region.ambient_sound, map_regions.allocator)
	}
	delete(map_regions.regions, map_regions.allocator)
	map_regions^ = {}
}

// True when the region carries a weather effect at all.
has_weather :: proc(region: Region) -> bool {
	return region.weather_id != {0, 0, 0, 0}
}

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

// Reads the region count and validates it against the remaining bytes
// before the caller allocates. The arithmetic runs in i64 so a huge
// declared count cannot wrap a product into a passing check on a
// 32-bit int target.
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

// Parses a complete war3map.w3r file. On error the partially built
// value is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (map_regions: Map_Regions, error: Error) {
	building: Map_Regions
	building.allocator = allocator
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
	if version != SUPPORTED_VERSION {
		return {}, .Unsupported_Version
	}
	building.version = version

	// Four bounds, a creation number, a weather id and a colour, plus
	// at minimum the NUL terminator of each of the two strings.
	count := read_count(&reader, 4 * 4 + 1 + 4 + 4 + 1 + 4) or_return
	building.regions = make([]Region, count, allocator)
	for &region in building.regions {
		left, left_ok := read_f32(&reader)
		bottom, bottom_ok := read_f32(&reader)
		right, right_ok := read_f32(&reader)
		top, top_ok := read_f32(&reader)
		if !left_ok || !bottom_ok || !right_ok || !top_ok {
			return {}, .Truncated
		}
		region.left = left
		region.bottom = bottom
		region.right = right
		region.top = top
		region.name = read_string(&reader, allocator) or_return
		creation_number, creation_number_ok := read_i32(&reader)
		if !creation_number_ok || !read_bytes(&reader, region.weather_id[:]) {
			return {}, .Truncated
		}
		region.creation_number = creation_number
		region.ambient_sound = read_string(&reader, allocator) or_return
		if !read_bytes(&reader, region.color_bgra[:]) {
			return {}, .Truncated
		}
	}

	// Exact end-of-file; every stock map ends here.
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Data
	}
	return building, .None
}
