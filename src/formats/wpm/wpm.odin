package wpm

// Reader for war3map.wpm, the per-cell pathing grid a Warcraft III
// map is collided against: magic "MP3W", u32 version (0, the only
// version that exists), u32 width, u32 height, then width * height
// flag bytes, row-major with the first row at the bottom (same
// orientation as the w3e tilepoint grid; established empirically, see
// the polarity note below). Cells are 32x32 world units, a 4x4
// subgrid per terrain tile, so against the same map's w3e grid
// width == 4 * (w3e.width - 1) and height == 4 * (w3e.height - 1)
// (verified over all 186 stock maps, WI-0010; asserted in the corpus
// sweep).
//
// Layout reference: War3Net's MapPathingMap reader and PathingType
// enum (MIT, license verified; docs/research/file-formats.md).
//
// Bit polarity: War3Net names the bits Walk/Fly/Build/Blight/Water
// without saying whether a set bit allows or blocks. Pinned
// empirically over all 186 stock maps by correlating cells with the
// same map's w3e terrain (WI-0010 probes):
// - Cells on boundary-flagged border tiles carry bits 0x02/0x04/0x08
//   at 99.3%/97.5%/99.6%, while open dry interior land carries 0x02
//   on only 31% of cells: a set bit BLOCKS (no-walk/no-fly/no-build).
// - 0x02 is set on 99.6-100% of cells over water deeper than ~1.25
//   height steps and on 15-24% of shallower water: ground units wade
//   shallow water, deep water is walk-blocked.
// - 0x40 is set on 99.9% of dry-land cells and clear on water: it
//   means NO water (blocks water pathing, e.g. for boats).
// - 0x20 matches the w3e blight flag exactly (set on 3849/3849 cells
//   over blighted tiles, 0/3809012 over clean ones): set means
//   blighted, the one positively-phrased bit.
// - 0x80 (unknown to War3Net too) is observed set on the unplayable
//   border cells outside the camera bounds.

import "base:runtime"

Error :: enum {
	None,
	Invalid_Magic,
	Unsupported_Version,
	Truncated_Header,
	Invalid_Dimensions,
}

SUPPORTED_VERSION :: 0

// Cell flag bits. A set bit blocks the movement type (except BLIGHT,
// which is presence); see the polarity note in the package comment.
CELL_NO_WALK: u8 : 0x02
CELL_NO_FLY: u8 : 0x04
CELL_NO_BUILD: u8 : 0x08
CELL_BLIGHT: u8 : 0x20
CELL_NO_WATER: u8 : 0x40
CELL_UNKNOWN_0X80: u8 : 0x80

Pathing_Map :: struct {
	width:     u32,
	height:    u32,
	// Row-major raw flag bytes, first row at the bottom. Kept raw
	// (rather than a bit_set type) so the unused bits 0x01/0x10 and
	// the unknown 0x80 survive round-tripping and inspection.
	cells:     []u8,
	allocator: runtime.Allocator,
}

destroy :: proc(pathing_map: ^Pathing_Map) {
	delete(pathing_map.cells, pathing_map.allocator)
	pathing_map^ = {}
}

// Returns the flag byte of the cell at (x, y); (0, 0) is the
// bottom-left corner.
cell :: proc(pathing_map: ^Pathing_Map, x: int, y: int) -> u8 {
	if x < 0 || y < 0 || x >= int(pathing_map.width) || y >= int(pathing_map.height) {
		return 0
	}
	return pathing_map.cells[y * int(pathing_map.width) + x]
}

@(private)
read_u32 :: proc(data: []u8, offset: int) -> u32 {
	return u32(data[offset]) | u32(data[offset + 1]) << 8 | u32(data[offset + 2]) << 16 | u32(data[offset + 3]) << 24
}

// Parses a complete war3map.wpm file. On error a zero value is
// returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (pathing_map: Pathing_Map, error: Error) {
	if len(data) < 4 || string(data[:4]) != "MP3W" {
		return {}, .Invalid_Magic
	}
	if len(data) < 16 {
		return {}, .Truncated_Header
	}
	if read_u32(data, 4) != SUPPORTED_VERSION {
		return {}, .Unsupported_Version
	}
	width := read_u32(data, 8)
	height := read_u32(data, 12)

	// The corpus stores exactly width * height cell bytes and nothing
	// after them (all 186 stock maps, WI-0010). Product in i64 so a
	// large dimension pair cannot wrap into a passing check on a
	// 32-bit target; checked before the allocation.
	if i64(width) * i64(height) != i64(len(data) - 16) {
		return {}, .Invalid_Dimensions
	}

	building: Pathing_Map
	building.allocator = allocator
	building.width = width
	building.height = height
	building.cells = make([]u8, len(data) - 16, allocator)
	copy(building.cells, data[16:])
	return building, .None
}
