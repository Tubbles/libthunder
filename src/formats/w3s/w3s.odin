package w3s

// Reader for war3map.w3s, the sound definitions a map's triggers refer
// to by their "gg_snd_*" variable names. The file has no magic: it
// opens with an int32 version, then an int32 sound count, then that
// many sound records. 29 of the 186 stock 1.29.2 maps carry one
// (WI-0010 survey), all declaring version 1.
//
// Per sound the file stores three NUL-terminated strings followed by
// seventeen four-byte fields:
//     name, file path, EAX setting,
//     flags i32, fade-in rate i32, fade-out rate i32, volume i32,
//     pitch f32, pitch variance f32, priority i32, channel i32,
//     minimum distance f32, maximum distance f32,
//     distance cutoff f32, cone angle inside f32,
//     cone angle outside f32, cone outside volume i32,
//     cone orientation x/y/z f32
// Field list and order from War3Net's Sound reader (MIT, license
// verified; docs/research/file-formats.md), matched field for field by
// wc3lib's sound.hpp, which names the last six of them only as
// "unknown" but annotates them with the matching JASS natives
// (SetSoundConeAngles takes inside, outside, outsideVolume;
// SetSoundConeOrientation takes x, y, z).
//
// Corpus-resolved: which of the seventeen fields are integers and
// which are floats. The two references agree, and the corpus confirms
// them without appeal to either. Unset fields carry a per-type
// sentinel: 0xFFFFFFFF (-1) for integers and 0x4F800000 (2^32 as f32)
// for floats. Across all 632 sounds in the corpus the float sentinel
// appears only in the ten float slots and the integer sentinel only in
// the four "unset-able" integer slots (volume, priority, channel, cone
// outside volume), with no crossover in either direction.
//
// Later versions: v2 (patch 1.32) appends a repeated name/path pair,
// an SLK display name, dialogue keys and FacialAnimation fields, and
// v3 (patch 1.32.6) one further int32. Both are out of the 1.29b
// parity target and are rejected by version rather than mis-read.
//
// TRIGSTR_ note: sound names are plain identifiers, not war3map.wts
// string references; the file paths are archive-relative.

import "base:runtime"
import "core:strings"

Error :: enum {
	None,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Unterminated_String,
	Trailing_Bytes,
}

SUPPORTED_VERSION :: 1

// Four-byte fields per sound record, after the three strings.
SOUND_FIELD_COUNT :: 17

// Flag bits, named identically by War3Net and wc3lib. Bit 4 is
// unknown to both. Observed flag words in the corpus range over
// 0 to 22, so no bit above 0x10 is ever set.
FLAG_LOOPING: u32 : 0x0000_0001
FLAG_3D_SOUND: u32 : 0x0000_0002
FLAG_STOP_WHEN_OUT_OF_RANGE: u32 : 0x0000_0004
FLAG_MUSIC: u32 : 0x0000_0008
FLAG_UNKNOWN_0X10: u32 : 0x0000_0010

// The "use the value from the SLK sound table instead" sentinels the
// editor writes into fields the author left alone.
UNSET_INTEGER: i32 : -1
UNSET_FLOAT: f32 : 4294967296.0 // 2^32, stored as 0x4F800000

// Channel numbers, from War3Net's SoundChannel enum, matched value for
// value by wc3lib's Channel enum up to Fire; the corpus only exercises
// General, Combat, Looping_Movement, Looping_Ambient and Animations,
// plus UNSET_INTEGER on 428 of its 632 sounds.
CHANNEL_GENERAL: i32 : 0
CHANNEL_UNIT_SELECTION: i32 : 1
CHANNEL_UNIT_ACKNOWLEDGEMENT: i32 : 2
CHANNEL_UNIT_MOVEMENT: i32 : 3
CHANNEL_UNIT_READY: i32 : 4
CHANNEL_COMBAT: i32 : 5
CHANNEL_ERROR: i32 : 6
CHANNEL_MUSIC: i32 : 7
CHANNEL_USER_INTERFACE: i32 : 8
CHANNEL_LOOPING_MOVEMENT: i32 : 9
CHANNEL_LOOPING_AMBIENT: i32 : 10
CHANNEL_ANIMATIONS: i32 : 11
CHANNEL_CONSTRUCTION: i32 : 12
CHANNEL_BIRTH: i32 : 13
CHANNEL_FIRE: i32 : 14

Sound :: struct {
	// Trigger variable name, "gg_snd_" prefixed in editor-authored files.
	name:                string,
	// Archive- or game-data-relative path of the wav to play.
	file_path:           string,
	// EAX reverb preset name, empty for the SLK default. The corpus
	// uses "", DefaultEAXON, CombatSoundsEAX, DoodadsEAX, HeroAcksEAX,
	// MissilesEAX and SpellsEAX.
	eax_setting:         string,
	flags:               u32,
	fade_in_rate:        i32,
	fade_out_rate:       i32,
	volume:              i32, // UNSET_INTEGER for the SLK default
	pitch:               f32,
	// Applied only when the SLK RANDOMPITCH flag is set.
	pitch_variance:      f32,
	priority:            i32,
	channel:             i32, // one of the CHANNEL_ constants
	// 3D distance parameters (JASS SetSoundDistances).
	minimum_distance:    f32,
	maximum_distance:    f32,
	distance_cutoff:     f32,
	// 3D cone parameters (JASS SetSoundConeAngles).
	cone_angle_inside:   f32,
	cone_angle_outside:  f32,
	cone_outside_volume: i32,
	// JASS SetSoundConeOrientation x, y, z.
	cone_orientation:    [3]f32,
}

Map_Sounds :: struct {
	version:   i32,
	sounds:    []Sound,
	allocator: runtime.Allocator,
}

destroy :: proc(map_sounds: ^Map_Sounds) {
	for sound in map_sounds.sounds {
		delete(sound.name, map_sounds.allocator)
		delete(sound.file_path, map_sounds.allocator)
		delete(sound.eax_setting, map_sounds.allocator)
	}
	delete(map_sounds.sounds, map_sounds.allocator)
	map_sounds^ = {}
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

// Reads the sound count and validates it against the remaining bytes
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

// Parses a complete war3map.w3s file. On error the partially built
// value is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (map_sounds: Map_Sounds, error: Error) {
	building: Map_Sounds
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

	// The seventeen fields plus at minimum a NUL terminator for each
	// of the three strings.
	count := read_count(&reader, 4 * SOUND_FIELD_COUNT + 3) or_return
	building.sounds = make([]Sound, count, allocator)
	for &sound in building.sounds {
		parse_sound(&reader, &sound, allocator) or_return
	}

	// Exact end-of-file: every one of the 32 w3s files in the corpus
	// (29 stock maps plus the demo campaign's three embedded maps)
	// ends here. This is also the guard against a v2/v3 record shape
	// slipping through with a v1 version field.
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Bytes
	}
	return building, .None
}

@(private)
parse_sound :: proc(reader: ^Reader, sound: ^Sound, allocator: runtime.Allocator) -> (error: Error) {
	sound.name = read_string(reader, allocator) or_return
	sound.file_path = read_string(reader, allocator) or_return
	sound.eax_setting = read_string(reader, allocator) or_return

	fields: [SOUND_FIELD_COUNT]u32
	for &field in fields {
		value, value_ok := read_u32(reader)
		if !value_ok {
			return .Truncated
		}
		field = value
	}
	sound.flags = fields[0]
	sound.fade_in_rate = i32(fields[1])
	sound.fade_out_rate = i32(fields[2])
	sound.volume = i32(fields[3])
	sound.pitch = transmute(f32)fields[4]
	sound.pitch_variance = transmute(f32)fields[5]
	sound.priority = i32(fields[6])
	sound.channel = i32(fields[7])
	sound.minimum_distance = transmute(f32)fields[8]
	sound.maximum_distance = transmute(f32)fields[9]
	sound.distance_cutoff = transmute(f32)fields[10]
	sound.cone_angle_inside = transmute(f32)fields[11]
	sound.cone_angle_outside = transmute(f32)fields[12]
	sound.cone_outside_volume = i32(fields[13])
	sound.cone_orientation = {
		transmute(f32)fields[14],
		transmute(f32)fields[15],
		transmute(f32)fields[16],
	}
	return .None
}
