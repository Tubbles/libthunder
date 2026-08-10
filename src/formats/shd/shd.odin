package shd

// Reader for war3map.shd, the baked terrain shadow mask of a Warcraft
// III map. The file has no header, no magic, and no version field at
// all: it is one byte per shadow sample, 0xFF shadowed, 0x00 not (the
// 1.29.2 stock corpus contains no other byte value in any of its 186
// maps; WI-0010 probe). Dimensions are not stored and must be derived
// from the same map's w3e grid.
//
// Pinned dimension invariant (WI-0010): for every one of the 186
// stock maps the byte length is exactly
//     16 * (w3e.width - 1) * (w3e.height - 1),
// i.e. 16 samples per terrain TILE (not per tilepoint), laid out as a
// 4x4 subgrid per tile. The competing candidate formulas
// (16 * width * height and the two mixed forms) matched zero maps, so
// the relationship is unambiguous. The sample grid is therefore
// 4 * (width - 1) columns by 4 * (height - 1) rows, row-major with
// the first row at the bottom: the same grid the wpm pathing cells
// use (a shadow sample and a pathing cell cover the same 32x32 world
// units; a rendered corpus shadow mask at this row width shows
// coherent unsheared shadow blobs).
//
// Layout references: War3Net's MapShadowMap (a bare read-to-end) and
// wc3lib's shadow.hpp; licenses verified in
// docs/research/file-formats.md.

import "base:runtime"

Error :: enum {
	None,
	Invalid_Dimensions,
	Length_Mismatch,
}

SAMPLES_PER_TILE :: 16

SHADOWED: u8 : 0xFF

Shadow_Map :: struct {
	// Sample grid dimensions, derived from the w3e grid:
	// 4 * (w3e.width - 1) by 4 * (w3e.height - 1).
	width:     u32,
	height:    u32,
	// Row-major, first row at the bottom; 0xFF shadowed, 0x00 not.
	samples:   []u8,
	allocator: runtime.Allocator,
}

destroy :: proc(shadow_map: ^Shadow_Map) {
	delete(shadow_map.samples, shadow_map.allocator)
	shadow_map^ = {}
}

// Returns the sample at (x, y); (0, 0) is the bottom-left corner.
sample :: proc(shadow_map: ^Shadow_Map, x: int, y: int) -> u8 {
	if x < 0 || y < 0 || x >= int(shadow_map.width) || y >= int(shadow_map.height) {
		return 0
	}
	return shadow_map.samples[y * int(shadow_map.width) + x]
}

// Parses a complete war3map.shd file against the tilepoint dimensions
// of the same map's war3map.w3e. The byte length must match the
// pinned invariant exactly; the arithmetic runs in i64 so large
// dimensions cannot wrap the product, and before the allocation.
parse :: proc(
	data: []u8,
	environment_width: u32,
	environment_height: u32,
	allocator := context.allocator,
) -> (
	shadow_map: Shadow_Map,
	error: Error,
) {
	if environment_width < 2 || environment_height < 2 {
		return {}, .Invalid_Dimensions
	}
	tile_columns := i64(environment_width) - 1
	tile_rows := i64(environment_height) - 1
	if SAMPLES_PER_TILE * tile_columns * tile_rows != i64(len(data)) {
		return {}, .Length_Mismatch
	}

	building: Shadow_Map
	building.allocator = allocator
	building.width = u32(4 * tile_columns)
	building.height = u32(4 * tile_rows)
	building.samples = make([]u8, len(data), allocator)
	copy(building.samples, data)
	return building, .None
}
