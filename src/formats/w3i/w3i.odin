package w3i

// Reader for war3map.w3i, the map info file of a Warcraft III map:
// name/author/description strings, camera bounds, playable area, map
// flags, tileset, loading/prologue screen data, (TFT) fog and
// environment settings, player slots, forces, upgrade/tech
// availability overrides, and random unit/item tables. The file has
// no magic; it starts directly with a u32 format version. Nearly
// every field is version-gated.
//
// Supported versions, corpus-driven (WI-0010 survey): v18 (Reign of
// Chaos, 45 stock maps) and v25 (The Frozen Throne, 141 stock maps).
// Later versions (v28+, patch 1.31 onward) are out of scope until a
// corpus needs them.
//
// The byte-exact reference for which field belongs to which version
// is War3Net's MapInfo reader and its Info/ sub-structure readers
// (MIT, license verified; docs/research/file-formats.md). Its
// version gates collapse for v18/v25 to the layout implemented in
// parse below, including two quirks mirrored deliberately:
// - a 0xFF byte in place of the upgrade-availability count marks the
//   rest of the file as absent (observed in protected maps);
// - the file may end cleanly right after the upgrade list.
//
// TRIGSTR_ note: most strings here (name, author, player names, ...)
// are "TRIGSTR_<n>" references into the same map's war3map.wts table
// (thunder:formats/wts); this reader stores them verbatim.

import "base:runtime"

Error :: enum {
	None,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Unterminated_String,
}

VERSION_REIGN_OF_CHAOS :: 18
VERSION_FROZEN_THRONE :: 25

Player :: struct {
	id:                   i32,
	controller:           i32, // 1 human, 2 computer, 3 neutral, 4 rescuable
	race:                 i32, // 1 human, 2 orc, 3 undead, 4 night elf
	flags:                u32, // bit 0: fixed start position
	name:                 string,
	start_x:              f32,
	start_y:              f32,
	ally_low_priorities:  u32, // bitmask over player slots
	ally_high_priorities: u32,
}

Force :: struct {
	flags:   u32,
	players: u32, // bitmask over player slots
	name:    string,
}

Upgrade_Availability :: struct {
	players:      u32, // bitmask over player slots
	id:           [4]u8, // upgrade rawcode
	level:        i32,
	availability: i32,
}

Tech_Availability :: struct {
	players: u32, // bitmask over player slots
	id:      [4]u8, // unit/item rawcode
}

Random_Unit_Line :: struct {
	chance:   i32, // percent
	unit_ids: [][4]u8, // one rawcode per table column
}

Random_Unit_Table :: struct {
	index:        i32,
	name:         string,
	widget_types: []i32, // per column: 0 unit, 1 building, 2 item
	lines:        []Random_Unit_Line,
}

Random_Item :: struct {
	chance: i32, // percent
	id:     [4]u8, // item rawcode
}

Random_Item_Set :: struct {
	items: []Random_Item,
}

Random_Item_Table :: struct {
	index:     i32,
	name:      string,
	item_sets: []Random_Item_Set,
}

Map_Info :: struct {
	version:                          u32,
	map_version:                      i32, // save counter
	editor_version:                   i32,
	name:                             string,
	author:                           string,
	description:                      string,
	recommended_players:              string,
	// (x, y) pairs: bottom-left, top-right, top-left, bottom-right.
	camera_bounds:                    [8]f32,
	// Margins in tiles: left, right, bottom, top.
	camera_bounds_complements:        [4]i32,
	playable_width:                   i32,
	playable_height:                  i32,
	flags:                            u32,
	tileset:                          u8, // tileset letter
	// v18 only.
	campaign_background_number:       i32,
	loading_screen_number:            i32,
	// v25 only.
	loading_screen_background_number: i32,
	loading_screen_path:              string,
	game_data_set:                    i32,
	prologue_screen_path:             string,
	// Both versions.
	loading_screen_text:              string,
	loading_screen_title:             string,
	loading_screen_subtitle:          string,
	prologue_screen_text:             string,
	prologue_screen_title:            string,
	prologue_screen_subtitle:         string,
	// v25 only from here to water_tint.
	fog_style:                        i32,
	fog_start_z:                      f32,
	fog_end_z:                        f32,
	fog_density:                      f32,
	fog_color:                        [4]u8, // stored order blue, green, red, alpha
	global_weather_id:                [4]u8, // rawcode, all zero when none
	sound_environment:                string,
	light_environment:                u8, // tileset letter, 0 for default
	water_tint:                       [4]u8, // stored order blue, green, red, alpha
	players:                          []Player,
	forces:                           []Force,
	upgrades:                         []Upgrade_Availability,
	techs:                            []Tech_Availability,
	random_unit_tables:               []Random_Unit_Table,
	random_item_tables:               []Random_Item_Table, // v25 only
	// Set when a 0xFF byte stood in place of the upgrade count and
	// the rest of the file was skipped (see package comment).
	tail_skipped:                     bool,
	allocator:                        runtime.Allocator,
}

destroy :: proc(info: ^Map_Info) {
	allocator := info.allocator
	delete(info.name, allocator)
	delete(info.author, allocator)
	delete(info.description, allocator)
	delete(info.recommended_players, allocator)
	delete(info.loading_screen_path, allocator)
	delete(info.prologue_screen_path, allocator)
	delete(info.loading_screen_text, allocator)
	delete(info.loading_screen_title, allocator)
	delete(info.loading_screen_subtitle, allocator)
	delete(info.prologue_screen_text, allocator)
	delete(info.prologue_screen_title, allocator)
	delete(info.prologue_screen_subtitle, allocator)
	delete(info.sound_environment, allocator)
	for player in info.players {
		delete(player.name, allocator)
	}
	delete(info.players, allocator)
	for force in info.forces {
		delete(force.name, allocator)
	}
	delete(info.forces, allocator)
	delete(info.upgrades, allocator)
	delete(info.techs, allocator)
	for table in info.random_unit_tables {
		delete(table.name, allocator)
		delete(table.widget_types, allocator)
		for line in table.lines {
			delete(line.unit_ids, allocator)
		}
		delete(table.lines, allocator)
	}
	delete(info.random_unit_tables, allocator)
	for table in info.random_item_tables {
		delete(table.name, allocator)
		for item_set in table.item_sets {
			delete(item_set.items, allocator)
		}
		delete(table.item_sets, allocator)
	}
	delete(info.random_item_tables, allocator)
	info^ = {}
}
