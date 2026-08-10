package w3e

// Reader for war3map.w3e, the terrain grid of a Warcraft III map: a
// header (tileset letter, custom-tileset flag, ground and cliff
// tileset id lists, grid dimensions, world offset of the bottom-left
// corner) followed by one 7-byte record per tilepoint (grid corner).
// Version 11 only, the sole version in the 1.29.2 stock map corpus
// (WI-0010 survey, 186/186 maps); v12 (patch 2.0.3) widens the packed
// texture byte and is out of scope until a corpus needs it.
//
// Layout references (reading permitted, licenses verified in
// docs/research/file-formats.md): War3Net's MapEnvironment and
// TerrainTile readers (MIT, byte-exact), the HiveWE wiki page for
// war3map.w3e, wc3lib as cross-check.
//
// Package layout note (WI-0010): the five map subformats live as one
// package per format under src/formats/ (w3e, wpm, shd, w3i, wts),
// matching the repo's one-format-one-package pattern. shd is tiny;
// that is fine. The cross-format corpus sweep lives in the w3i
// package, the only one whose data references the other four.

import "base:runtime"

Error :: enum {
	None,
	Invalid_Magic,
	Unsupported_Version,
	Truncated_Header,
	Invalid_List_Count,
	Invalid_Dimensions,
}

SUPPORTED_VERSION :: 11

Tilepoint_Flag :: enum u8 {
	Ramp     = 0,
	Blight   = 1,
	Water    = 2,
	Boundary = 3,
}

Tilepoint_Flags :: bit_set[Tilepoint_Flag;u8]

Tilepoint :: struct {
	// Raw 16-bit ground height; world height steps are
	// (raw - 8192) / 512 (War3Net TerrainTile.Height).
	ground_height:   u16,
	// Raw 14-bit water level, same scale as ground_height.
	water_level:     u16,
	// Bit 14 of the water field, set on map-edge tilepoints (War3Net
	// IsEdgeTile; HiveWE calls it a boundary flag).
	edge_flag:       bool,
	ground_texture:  u8, // index into ground_tileset_ids (4 bits in v11)
	flags:           Tilepoint_Flags,
	variation:       u8, // ground texture variation
	cliff_variation: u8,
	cliff_level:     u8, // cliff layer
	cliff_texture:   u8, // index into cliff_tileset_ids
}

Environment :: struct {
	tileset:            u8, // tileset letter, e.g. 'L' Lordaeron Summer
	is_custom_tileset:  bool,
	ground_tileset_ids: [][4]u8,
	cliff_tileset_ids:  [][4]u8,
	// Grid dimensions in tilepoints, exactly as stored in the file;
	// the tile grid between them is (width - 1) x (height - 1).
	width:              u32,
	height:             u32,
	// World coordinates of the bottom-left corner.
	left:               f32,
	bottom:             f32,
	// Row-major, width tilepoints per row, first row at the bottom
	// (the header offset names the left/bottom corner; HiveWE).
	tilepoints:         []Tilepoint,
	allocator:          runtime.Allocator,
}

destroy :: proc(environment: ^Environment) {
	delete(environment.ground_tileset_ids, environment.allocator)
	delete(environment.cliff_tileset_ids, environment.allocator)
	delete(environment.tilepoints, environment.allocator)
	environment^ = {}
}

// Returns the tilepoint at grid position (x, y); (0, 0) is the
// bottom-left corner.
tilepoint :: proc(environment: ^Environment, x: int, y: int) -> Tilepoint {
	if x < 0 || y < 0 || x >= int(environment.width) || y >= int(environment.height) {
		return {}
	}
	return environment.tilepoints[y * int(environment.width) + x]
}

@(private)
read_u32 :: proc(data: []u8, offset: int) -> u32 {
	return u32(data[offset]) | u32(data[offset + 1]) << 8 | u32(data[offset + 2]) << 16 | u32(data[offset + 3]) << 24
}

// Parses a complete war3map.w3e file. On error the partially built
// environment is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (environment: Environment, error: Error) {
	building: Environment
	building.allocator = allocator
	defer if error != .None {
		destroy(&building)
	}

	if len(data) < 4 || string(data[:4]) != "W3E!" {
		return {}, .Invalid_Magic
	}
	if len(data) < 8 {
		return {}, .Truncated_Header
	}
	if read_u32(data, 4) != SUPPORTED_VERSION {
		return {}, .Unsupported_Version
	}
	if len(data) < 17 {
		return {}, .Truncated_Header
	}
	building.tileset = data[8]
	building.is_custom_tileset = read_u32(data, 9) != 0

	offset := 13
	parse_id_list(data, &offset, &building.ground_tileset_ids, allocator) or_return
	parse_id_list(data, &offset, &building.cliff_tileset_ids, allocator) or_return

	if len(data) - offset < 16 {
		return {}, .Truncated_Header
	}
	building.width = read_u32(data, offset)
	building.height = read_u32(data, offset + 4)
	building.left = transmute(f32)read_u32(data, offset + 8)
	building.bottom = transmute(f32)read_u32(data, offset + 12)
	offset += 16

	// The corpus stores exactly width * height tilepoint records and
	// nothing after them (verified over all 186 stock maps, WI-0010);
	// a mismatch means a corrupt or truncated file. Arithmetic in i64
	// so a large dimension pair cannot wrap the product on a 32-bit
	// target, and the check runs before the allocation.
	if building.width == 0 || building.height == 0 {
		return {}, .Invalid_Dimensions
	}
	tilepoint_count := i64(building.width) * i64(building.height)
	if tilepoint_count * 7 != i64(len(data) - offset) {
		return {}, .Invalid_Dimensions
	}

	building.tilepoints = make([]Tilepoint, int(tilepoint_count), allocator)
	for &point in building.tilepoints {
		point = decode_tilepoint(data[offset:offset + 7])
		offset += 7
	}
	return building, .None
}

@(private)
parse_id_list :: proc(data: []u8, offset: ^int, list: ^[][4]u8, allocator: runtime.Allocator) -> Error {
	if len(data) - offset^ < 4 {
		return .Truncated_Header
	}
	count := read_u32(data, offset^)
	offset^ += 4
	if i64(count) * 4 > i64(len(data) - offset^) {
		return .Invalid_List_Count
	}
	list^ = make([][4]u8, int(count), allocator)
	for &id in list^ {
		copy(id[:], data[offset^:offset^ + 4])
		offset^ += 4
	}
	return .None
}

// v11 tilepoint record: u16 ground height, u16 water level (low 14
// bits) plus edge flag (bit 14), one byte packing the ground texture
// (low nibble) with the ramp/blight/water/boundary flags (high
// nibble), one byte packing ground variation (low nibble) with cliff
// variation (high nibble), one byte packing cliff level (low nibble)
// with cliff texture (high nibble). Per War3Net's TerrainTile.
@(private)
decode_tilepoint :: proc(record: []u8) -> (point: Tilepoint) {
	point.ground_height = u16(record[0]) | u16(record[1]) << 8
	water_and_edge := u16(record[2]) | u16(record[3]) << 8
	point.water_level = water_and_edge & 0x3FFF
	point.edge_flag = water_and_edge & 0x4000 != 0
	point.ground_texture = record[4] & 0x0F
	point.flags = transmute(Tilepoint_Flags)u8(record[4] >> 4)
	point.variation = record[5] & 0x0F
	point.cliff_variation = record[5] >> 4
	point.cliff_level = record[6] & 0x0F
	point.cliff_texture = record[6] >> 4
	return point
}
