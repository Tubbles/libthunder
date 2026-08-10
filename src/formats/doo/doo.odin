package doo

// Reader for the two Warcraft III placement files, which share the
// magic "W3do" and the same two-integer version scheme but carry
// different entry layouts:
//
// - war3mapUnits.doo (capital U): every placed unit and item in one
//   flat list. Whether an entry is a unit or an item is decided by
//   which gameplay table its 4-character type id resolves against,
//   which is sim-layer work, not this parser's.
// - war3map.doo: every placed doodad and destructable in one list,
//   followed by a separate section of cliff-attached "special" terrain
//   doodads that the editor cannot edit once placed. That section
//   carries its own version integer, always 0.
//
// Supported versions, corpus-driven (WI-0010 survey, reconfirmed here
// by parsing both files of all 186 stock maps): v7 with sub-version 9
// in the 45 Reign of Chaos maps and v8 with sub-version 11 in the 141
// Frozen Throne maps, for both files. No other pair occurs, so any
// other pair is rejected rather than guessed at.
//
// The byte-exact reference for field order and version gating is
// War3Net's MapUnits/UnitData and MapDoodads/DoodadData readers (MIT,
// license verified; docs/research/file-formats.md), cross-checked
// against the HiveWE wiki's prose layout for both files. Where the two
// disagree the corpus decided; each such point is commented at its
// parse site in doo_parse.odin.
//
// Reforged (patch 1.32+) added a per-entry skin id to both files
// without bumping either version integer, and the only known way to
// detect it is War3Net's heuristic of sniffing whether the next byte
// looks printable. That heuristic is deliberately not implemented: no
// corpus file has the field, and every entry read here is exact-size
// with a whole-file exact-EOF check at the end, so a Reforged file
// fails with Truncated or Trailing_Bytes instead of mis-parsing.

import "base:runtime"

Error :: enum {
	None,
	Bad_Magic,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Trailing_Bytes,
}

MAGIC :: "W3do"

VERSION_REIGN_OF_CHAOS :: 7
VERSION_FROZEN_THRONE :: 8
SUB_VERSION_REIGN_OF_CHAOS :: 9
SUB_VERSION_FROZEN_THRONE :: 11

// The special-doodad section's own version. Only 0 has ever existed.
SPECIAL_DOODAD_VERSION :: 0

// The item_table_id value meaning "drops nothing from a shared table".
// Also what this reader stores for v7 entries, which have no such
// field at all.
NO_ITEM_TABLE :: -1

Dropped_Item :: struct {
	id:     [4]u8, // item rawcode, may be a random-item id ("YYI4")
	chance: i32, // percent
}

// One "drop one of these" group. A destructable or unit rolls each of
// its sets separately when it dies.
Dropped_Item_Set :: struct {
	items: []Dropped_Item,
}

Inventory_Item :: struct {
	slot: i32, // zero indexed, 0..5
	id:   [4]u8, // item rawcode
}

Modified_Ability :: struct {
	id:              [4]u8, // ability rawcode
	autocast_active: i32, // stored as a 4-byte boolean
	level:           i32,
}

Random_Unit_Choice :: struct {
	id:     [4]u8, // unit rawcode
	chance: i32, // percent
}

// Mode 0: any neutral passive building or item of a given level and
// item class. The level is stored as a signed 24-bit integer; -1 means
// any level.
Random_Any :: struct {
	level:      i32,
	item_class: u8, // 0 any/units, 1..6 item classes, 8 any
}

// Mode 1: a column of one of the random unit tables defined in
// war3map.w3i.
Random_Global_Table :: struct {
	table_id: i32,
	column:   i32,
}

// Mode 2: a table of weighted choices stored inline in the entry.
Random_Custom_Table :: struct {
	choices: []Random_Unit_Choice,
}

Random_Unit :: union {
	Random_Any,
	Random_Global_Table,
	Random_Custom_Table,
}

RANDOM_MODE_ANY :: 0
RANDOM_MODE_GLOBAL_TABLE :: 1
RANDOM_MODE_CUSTOM_TABLE :: 2

Placed_Unit :: struct {
	type_id:             [4]u8, // unit or item rawcode
	variation:           i32,
	// World coordinates, relative to the war3map.w3e terrain offsets.
	position:            [3]f32,
	rotation:            f32, // radians
	scale:               [3]f32,
	// Corpus: 2 in all but four entries, which hold 3. The HiveWE wiki
	// reads bit 0x02 as "not used in script" and bit 0x04 as a fixed-Z
	// flag the editor cannot set.
	flags:               u8,
	owning_player:       i32, // zero indexed, 12 is neutral hostile
	// Two bytes the references agree are unknown; zero in every corpus
	// entry (see doo_parse.odin for what else they could be).
	unknown_byte_1:      u8,
	unknown_byte_2:      u8,
	hit_points:          i32, // -1 for the unit's default
	mana_points:         i32, // -1 for the unit's default
	// v8 only, NO_ITEM_TABLE in v7 files: index of a war3map.w3i
	// random item table dropped on death, or NO_ITEM_TABLE.
	item_table_id:       i32,
	dropped_item_sets:   []Dropped_Item_Set,
	gold_amount:         i32,
	target_acquisition:  f32, // -1 normal, -2 camp
	hero_level:          i32, // 1 for non-heroes and items
	// v8 only, zero in v7 files. Zero means "use the hero's default".
	hero_strength:       i32,
	hero_agility:        i32,
	hero_intelligence:   i32,
	inventory:           []Inventory_Item,
	modified_abilities:  []Modified_Ability,
	// Stored verbatim. 0, 1 and 2 select the three random_data shapes;
	// any other value carries no random_data at all (corpus: -1 in
	// 2367 entries, 641 in 10 entries of one map).
	random_mode:         i32,
	random_data:         Random_Unit,
	custom_color:        i32, // -1 none, else a player color index
	waygate_destination: i32, // -1 none, else a war3map.w3r region id
	creation_number:     i32, // World Editor identity, not unique
}

Placed_Units :: struct {
	version:     i32,
	sub_version: i32,
	units:       []Placed_Unit,
	allocator:   runtime.Allocator,
}

Placed_Doodad :: struct {
	type_id:           [4]u8, // doodad or destructable rawcode
	variation:         i32, // model variation, appended to the model name
	position:          [3]f32,
	rotation:          f32, // radians
	scale:             [3]f32,
	// The HiveWE wiki reads bit 0x01 as "outside the playable area",
	// 0x02 as "not used in script" and 0x04 as "retain Z when moving".
	// Corpus values: 0, 2, 3, 4, 6, 7.
	flags:             u8,
	// Percentage of the destructable's maximum life. Corpus values: 0,
	// 40, 50, 100 and 255, the last on plain doodads with no life.
	life_percentage:   u8,
	// v8 only, NO_ITEM_TABLE in v7 files (v7 has no drop data at all).
	item_table_id:     i32,
	dropped_item_sets: []Dropped_Item_Set,
	creation_number:   i32,
}

// A cliff-attached terrain doodad. Placed on the tile grid rather than
// in world coordinates and not editable once placed.
Special_Doodad :: struct {
	type_id:   [4]u8,
	variation: i32, // zero in every corpus entry
	grid_x:    i32, // whole grid cells from the bottom-left corner
	grid_y:    i32,
}

Placed_Doodads :: struct {
	version:                i32,
	sub_version:            i32,
	doodads:                []Placed_Doodad,
	special_doodad_version: i32, // always SPECIAL_DOODAD_VERSION
	special_doodads:        []Special_Doodad,
	allocator:              runtime.Allocator,
}

destroy :: proc {
	destroy_units,
	destroy_doodads,
}

destroy_units :: proc(placed: ^Placed_Units) {
	allocator := placed.allocator
	for unit in placed.units {
		destroy_item_sets(unit.dropped_item_sets, allocator)
		delete(unit.inventory, allocator)
		delete(unit.modified_abilities, allocator)
		if custom_table, is_custom_table := unit.random_data.(Random_Custom_Table); is_custom_table {
			delete(custom_table.choices, allocator)
		}
	}
	delete(placed.units, allocator)
	placed^ = {}
}

destroy_doodads :: proc(placed: ^Placed_Doodads) {
	allocator := placed.allocator
	for doodad in placed.doodads {
		destroy_item_sets(doodad.dropped_item_sets, allocator)
	}
	delete(placed.doodads, allocator)
	delete(placed.special_doodads, allocator)
	placed^ = {}
}

@(private)
destroy_item_sets :: proc(item_sets: []Dropped_Item_Set, allocator: runtime.Allocator) {
	for item_set in item_sets {
		delete(item_set.items, allocator)
	}
	delete(item_sets, allocator)
}
