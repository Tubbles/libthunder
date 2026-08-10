package mmp

// Reader for war3map.mmp, the static minimap preview icons the game
// draws over a map's preview image in the map-selection menu: gold
// mines, neutral buildings and player start locations. These are
// editor-authored and persistent; they are not player pings, which are
// transient network messages never written to any file.
//
// The file has no magic: an int32 version, an int32 icon count, then
// that many 16-byte icon records of
//     i32 type, i32 x, i32 y, u8[4] colour (blue green red alpha).
// Every one of the 186 stock 1.29.2 maps declares version 0, the only
// version that has ever existed (WI-0010 survey). Layout and the icon
// type numbering from War3Net's PreviewIcon reader and PreviewIconType
// enum (MIT, license verified; docs/research/file-formats.md), with
// wc3lib's menuminimap.hpp agreeing on the shape.
//
// Corpus-resolved facts (all 4551 icons of the 186 stock maps):
// - The colour is stored blue, green, red, alpha, as War3Net's
//   ReadColorBgra says. The corpus proves it independently of any
//   reference: all twelve stock player colours appear on
//   start-location icons and only come out right in this byte order.
//   Player 1 red (0xFF0303) is stored 03 03 FF FF, player 2 blue
//   (0x0042FF) is stored FF 42 00 FF, player 3 teal (0x1CE6B9) is
//   stored B9 E6 1C FF, and so on down to player 12 brown (0x4E2A04)
//   stored 04 2A 4E FF. A further 26 of the 1053 start-location icons
//   use off-palette colours, so the colour is free-form data rather
//   than a player-slot index. Alpha is 255 throughout.
// - Gold-mine and neutral-building icons are always opaque white.
// - x and y are preview-image pixel coordinates, not world units: the
//   corpus values span 4 to 251 and -6 to 253 against a 256x256
//   preview, so an icon can sit slightly outside the image.
// - Unlike w3c and w3r, no stock map ships an empty icon list.

import "base:runtime"

Error :: enum {
	None,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Trailing_Data,
}

SUPPORTED_VERSION :: 0

ICON_RECORD_SIZE :: 16

// Icon type numbering from War3Net's PreviewIconType. Stored as an i32
// on the icon so an unknown future value survives parsing.
ICON_TYPE_GOLD_MINE :: 0
ICON_TYPE_NEUTRAL_BUILDING :: 1
ICON_TYPE_PLAYER_START_LOCATION :: 2

Preview_Icon :: struct {
	type:       i32,
	// Pixel position on the map preview image.
	x:          i32,
	y:          i32,
	// Icon tint in file order: blue, green, red, alpha.
	color_bgra: [4]u8,
}

Map_Preview_Icons :: struct {
	version:   i32,
	icons:     []Preview_Icon,
	allocator: runtime.Allocator,
}

destroy :: proc(preview_icons: ^Map_Preview_Icons) {
	delete(preview_icons.icons, preview_icons.allocator)
	preview_icons^ = {}
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
read_bytes :: proc(reader: ^Reader, buffer: []u8) -> bool {
	if reader_remaining(reader) < len(buffer) {
		return false
	}
	copy(buffer, reader.data[reader.offset:])
	reader.offset += len(buffer)
	return true
}

// Reads the icon count and validates it against the remaining bytes
// before the caller allocates. The arithmetic runs in i64 so a huge
// declared count cannot wrap a product into a passing check on a
// 32-bit int target.
@(private)
read_count :: proc(reader: ^Reader, element_size: i64) -> (count: int, error: Error) {
	raw, ok := read_u32(reader)
	if !ok {
		return 0, .Truncated
	}
	if i64(raw) * element_size > i64(reader_remaining(reader)) {
		return 0, .Invalid_Count
	}
	return int(raw), .None
}

// Parses a complete war3map.mmp file. On error the partially built
// value is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (preview_icons: Map_Preview_Icons, error: Error) {
	building: Map_Preview_Icons
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

	count := read_count(&reader, ICON_RECORD_SIZE) or_return
	building.icons = make([]Preview_Icon, count, allocator)
	for &icon in building.icons {
		type, type_ok := read_i32(&reader)
		x, x_ok := read_i32(&reader)
		y, y_ok := read_i32(&reader)
		if !type_ok || !x_ok || !y_ok || !read_bytes(&reader, icon.color_bgra[:]) {
			return {}, .Truncated
		}
		icon.type = type
		icon.x = x
		icon.y = y
	}

	// Exact end-of-file; every stock map ends here.
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Data
	}
	return building, .None
}
