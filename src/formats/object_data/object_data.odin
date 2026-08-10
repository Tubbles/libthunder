package object_data

// Reader for the seven Warcraft III object-editor data files:
// war3map.w3u (units), .w3t (items), .w3b (destructables), .w3d
// (doodad types), .w3a (abilities), .w3h (buffs/effects), .w3q
// (upgrades), plus the war3campaign.* variants carried by .w3n
// campaign archives (same format, different member name). These files
// hold per-field modifications to Blizzard's standard entries and
// definitions of new custom entries, overriding the SLK gameplay
// tables when a map is loaded.
//
// One container format with two shapes (WI-0011):
// - Simple (w3u, w3t, w3b, w3h): each modification is a 4-character
//   modification id, a value-type tag, the value, and an end token.
// - Leveled (w3a, w3q, w3d): two extra int32 fields between the tag
//   and the value: a level (a variation index for w3d) and a data
//   pointer selecting the SLK data column (corpus range 0..6,
//   mapping A, B, C, D, F, G, H, skipping E, per the HiveWE wiki).
//
// Supported versions, corpus-driven (WI-0011 probe over all 186
// stock maps plus DemoCampaign.w3n and its three embedded maps): v1
// (13 files) and v2 (48 files). The references (War3Net, wc3lib,
// HiveWE wiki; docs/research/file-formats.md) agree that v1 and v2
// share one layout: their only structural branch is at v3 (patch
// 1.33 per-object modification sets), which is out of scope until a
// corpus needs it. The corpus's lone leveled v1 file,
// (4)Monolith.w3x's war3map.w3a, confirms the level and data-pointer
// fields are present in v1 too.

import "base:runtime"

Error :: enum {
	None,
	Truncated,
	Unsupported_Version,
	Invalid_Count,
	Unknown_Value_Type,
	Unterminated_String,
	Trailing_Bytes,
}

// Both corpus-observed versions share one binary layout (see the
// package comment).
MINIMUM_VERSION :: 1
MAXIMUM_VERSION :: 2

Shape :: enum {
	Simple, // w3u, w3t, w3b, w3h
	Leveled, // w3a, w3q (level), w3d (variation)
}

// The value-type tag stored in the file. War3Net additionally lists
// Bool = 4 and Char = 5, both marked obsolete; no corpus file uses
// them (WI-0011 probe: 15355 Integer, 1856 Real, 6557 Unreal, 19999
// String modifications, nothing else), so tags above String are
// rejected as Unknown_Value_Type until a corpus needs them.
Value_Type :: enum i32 {
	Integer = 0,
	Real    = 1,
	Unreal  = 2, // f32 like Real; the editor restricts it to 0..1
	String  = 3,
}

Value :: union {
	i32,
	f32,
	string,
}

Modification :: struct {
	id:           [4]u8, // 4-character modification id ("unam", ...)
	value_type:   Value_Type,
	// Leveled shape only, zero for the simple shape: the level (w3a,
	// w3q) or variation (w3d) the modification applies to, and the
	// SLK data column it targets.
	level:        i32,
	data_pointer: i32,
	value:        Value,
	// Trailing int32, stored verbatim. Corpus (61 files): 35628 are
	// zero, 7734 repeat the entry's old id, 405 hold unrelated
	// rawcodes (other object ids, next to "umdl"/"uico" string
	// modifications), so no value can be validated against; the
	// references agree it is unused (War3Net names it SanityCheck,
	// wc3lib and the HiveWE wiki an end token).
	end_token:    [4]u8,
}

Entry :: struct {
	// Original-table entries modify the standard object old_id and
	// leave new_id zero (all 61 corpus files); custom-table entries
	// derive new object new_id from standard object old_id (new_id
	// nonzero in all corpus files). Neither is enforced.
	old_id:        [4]u8,
	new_id:        [4]u8,
	modifications: []Modification,
}

Object_Data :: struct {
	version:   i32,
	shape:     Shape,
	original:  []Entry, // modifications to standard entries
	custom:    []Entry, // new entries
	allocator: runtime.Allocator,
}

// Maps a file extension (without the dot, "w3u" ... "w3q") to the
// shape it parses with; known is false for any other extension.
shape_for_extension :: proc(extension: string) -> (shape: Shape, known: bool) {
	switch extension {
	case "w3u", "w3t", "w3b", "w3h":
		return .Simple, true
	case "w3a", "w3q", "w3d":
		return .Leveled, true
	}
	return .Simple, false
}

destroy :: proc(object_data: ^Object_Data) {
	allocator := object_data.allocator
	destroy_table(object_data.original, allocator)
	destroy_table(object_data.custom, allocator)
	object_data^ = {}
}

@(private)
destroy_table :: proc(table: []Entry, allocator: runtime.Allocator) {
	for entry in table {
		for modification in entry.modifications {
			if text, is_text := modification.value.(string); is_text {
				delete(text, allocator)
			}
		}
		delete(entry.modifications, allocator)
	}
	delete(table, allocator)
}
