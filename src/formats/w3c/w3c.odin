package w3c

// Reader for war3map.w3c, the named editor camera presets a map's
// triggers can apply. The file has no magic: it opens with an int32
// version, then an int32 camera count, then that many camera records.
// Every one of the 186 stock 1.29.2 maps declares version 0, the only
// version that has ever existed (WI-0010 survey).
//
// Per camera the file stores ten f32 fields followed by a
// NUL-terminated name:
//     target x, target y, z offset, rotation, angle of attack,
//     distance, roll, field of view, far clipping plane,
//     near clipping plane
// Field list and order from War3Net's Camera reader (MIT, license
// verified; docs/research/file-formats.md), independently matched
// field for field by wc3lib's camera.hpp, whose tenth member is
// unnamed with the comment "100".
//
// Corpus-resolved: the count of ten. Secondary summaries variously
// call this an eight- or nine-float record; parsing the 10 stock maps
// that actually contain cameras (139 cameras in total, the other 176
// maps ship an eight-byte empty file) resolves it, since only ten
// floats per record lands on exactly end-of-file with clean names and
// plausible values. wc3lib's tenth field is the near clipping plane:
// it holds 100 in every stock camera, and War3Net names it so.
//
// Reforged extension: three further floats (local pitch, yaw, roll)
// were appended per camera at some point after 1.29 WITHOUT a version
// bump, so no declared field distinguishes the shapes. This reader is
// strict classic: it reads ten floats and requires the file to end
// exactly after the last name. A Reforged-shaped file therefore fails
// with Trailing_Data or Truncated rather than being mis-read. That
// guard is sound but not a proof of impossibility: because each
// record ends at a NUL, a longer record shape re-synchronises at the
// next camera, so a hand-built file could in principle land on
// end-of-file with the wrong shape. Name plausibility, not length,
// would be the discriminator if such a file ever showed up.

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

SUPPORTED_VERSION :: 0

// Floats per camera record in the classic (pre-Reforged) shape.
CAMERA_FLOAT_COUNT :: 10

Camera :: struct {
	// World position the camera looks at.
	target_x:            f32,
	target_y:            f32,
	// Height above the terrain at the target position.
	z_offset:            f32,
	// Degrees, counter-clockwise from the positive x axis.
	rotation:            f32,
	// Degrees; the stock corpus default is 304.
	angle_of_attack:     f32,
	// Distance from the camera to the target position.
	distance:            f32,
	roll:                f32,
	// Degrees; the stock corpus default is 70.
	field_of_view:       f32,
	far_clipping_plane:  f32,
	// wc3lib leaves this one unnamed; it is 100 in every stock camera.
	near_clipping_plane: f32,
	name:                string,
}

Map_Cameras :: struct {
	version:   i32,
	cameras:   []Camera,
	allocator: runtime.Allocator,
}

destroy :: proc(map_cameras: ^Map_Cameras) {
	for camera in map_cameras.cameras {
		delete(camera.name, map_cameras.allocator)
	}
	delete(map_cameras.cameras, map_cameras.allocator)
	map_cameras^ = {}
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

// Reads the camera count and validates it against the remaining bytes
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

// Parses a complete war3map.w3c file. On error the partially built
// value is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (map_cameras: Map_Cameras, error: Error) {
	building: Map_Cameras
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

	// The ten floats plus at minimum the name's NUL terminator.
	count := read_count(&reader, 4 * CAMERA_FLOAT_COUNT + 1) or_return
	building.cameras = make([]Camera, count, allocator)
	for &camera in building.cameras {
		fields: [CAMERA_FLOAT_COUNT]f32
		for &field in fields {
			value, value_ok := read_f32(&reader)
			if !value_ok {
				return {}, .Truncated
			}
			field = value
		}
		camera.target_x = fields[0]
		camera.target_y = fields[1]
		camera.z_offset = fields[2]
		camera.rotation = fields[3]
		camera.angle_of_attack = fields[4]
		camera.distance = fields[5]
		camera.roll = fields[6]
		camera.field_of_view = fields[7]
		camera.far_clipping_plane = fields[8]
		camera.near_clipping_plane = fields[9]
		camera.name = read_string(&reader, allocator) or_return
	}

	// Exact end-of-file. Every stock map ends here, and this is the
	// guard against the unsignaled Reforged camera shape.
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Data
	}
	return building, .None
}
