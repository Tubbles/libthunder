package w3i

// Synthetic-fixture tests: hand-built w3i byte streams for both
// supported versions, no game data.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_i32 :: proc(buffer: ^[dynamic]u8, value: i32) {
	test_append_u32(buffer, u32(value))
}

@(private)
test_append_f32 :: proc(buffer: ^[dynamic]u8, value: f32) {
	test_append_u32(buffer, transmute(u32)value)
}

@(private)
test_append_string :: proc(buffer: ^[dynamic]u8, text: string) {
	append(buffer, text)
	append(buffer, 0)
}

// Everything from the version int through the tileset byte, shared by
// both versions.
@(private)
test_append_common_header :: proc(file: ^[dynamic]u8, version: u32) {
	test_append_u32(file, version)
	test_append_i32(file, 7)
	test_append_i32(file, 6030)
	test_append_string(file, "TRIGSTR_001")
	test_append_string(file, "An Author")
	test_append_string(file, "A Description")
	test_append_string(file, "1v1")
	bounds := [8]f32{-1024, -1536, 1024, 1536, -1024, 1536, 1024, -1536}
	for bound in bounds {
		test_append_f32(file, bound)
	}
	complements := [4]i32{1, 2, 3, 4}
	for complement in complements {
		test_append_i32(file, complement)
	}
	test_append_i32(file, 32)
	test_append_i32(file, 24)
	test_append_u32(file, 0x1234)
	append(file, 'L')
}

// One player, one force, one upgrade, one tech, one random unit table
// with two columns and one line.
@(private)
test_append_common_lists :: proc(file: ^[dynamic]u8) {
	test_append_u32(file, 1)
	test_append_i32(file, 0)
	test_append_i32(file, 1)
	test_append_i32(file, 2)
	test_append_u32(file, 1)
	test_append_string(file, "TRIGSTR_000")
	test_append_f32(file, -512)
	test_append_f32(file, 256)
	test_append_u32(file, 0)
	test_append_u32(file, 2)

	test_append_u32(file, 1)
	test_append_u32(file, 0)
	test_append_u32(file, 0xFFFF_FFFF)
	test_append_string(file, "Force 1")

	test_append_u32(file, 1)
	test_append_u32(file, 0xFF)
	append(file, "Rhme")
	test_append_i32(file, 2)
	test_append_i32(file, 1)

	test_append_u32(file, 1)
	test_append_u32(file, 1)
	append(file, "hfoo")

	test_append_u32(file, 1)
	test_append_i32(file, 0)
	test_append_string(file, "Unit Table")
	test_append_u32(file, 2)
	test_append_i32(file, 0)
	test_append_i32(file, 2)
	test_append_u32(file, 1)
	test_append_i32(file, 50)
	append(file, "hfoo")
	append(file, "hpea")
}

@(private)
test_build_v18_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_common_header(&file, VERSION_REIGN_OF_CHAOS)
	test_append_i32(&file, -1)
	test_append_string(&file, "Loading Text")
	test_append_string(&file, "Loading Title")
	test_append_string(&file, "Loading Subtitle")
	test_append_i32(&file, -1)
	test_append_string(&file, "Prologue Text")
	test_append_string(&file, "Prologue Title")
	test_append_string(&file, "Prologue Subtitle")
	test_append_common_lists(&file)
	return file
}

@(private)
test_build_v25_file :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_common_header(&file, VERSION_FROZEN_THRONE)
	test_append_i32(&file, -1)
	test_append_string(&file, "LoadingScreen.mdx")
	test_append_string(&file, "Loading Text")
	test_append_string(&file, "Loading Title")
	test_append_string(&file, "Loading Subtitle")
	test_append_i32(&file, 0)
	test_append_string(&file, "Prologue.mdx")
	test_append_string(&file, "Prologue Text")
	test_append_string(&file, "Prologue Title")
	test_append_string(&file, "Prologue Subtitle")
	test_append_i32(&file, 0)
	test_append_f32(&file, 3000)
	test_append_f32(&file, 5000)
	test_append_f32(&file, 0.5)
	append(&file, 0, 0, 0, 255)
	append(&file, "RAhr")
	test_append_string(&file, "LakeEverGreenDay")
	append(&file, 'D')
	append(&file, 255, 255, 255, 255)
	test_append_common_lists(&file)
	// Random item tables: one table, one set, two items.
	test_append_u32(&file, 1)
	test_append_i32(&file, 0)
	test_append_string(&file, "Item Table")
	test_append_u32(&file, 1)
	test_append_u32(&file, 2)
	test_append_i32(&file, 30)
	append(&file, "ratc")
	test_append_i32(&file, 70)
	append(&file, "rde1")
	return file
}

@(private)
test_expect_common_fields :: proc(t: ^testing.T, info: ^Map_Info) {
	testing.expect_value(t, info.map_version, 7)
	testing.expect_value(t, info.editor_version, 6030)
	testing.expect_value(t, info.name, "TRIGSTR_001")
	testing.expect_value(t, info.author, "An Author")
	testing.expect_value(t, info.description, "A Description")
	testing.expect_value(t, info.recommended_players, "1v1")
	testing.expect_value(t, info.camera_bounds[0], -1024)
	testing.expect_value(t, info.camera_bounds[7], -1536)
	testing.expect_value(t, info.camera_bounds_complements[0], 1)
	testing.expect_value(t, info.camera_bounds_complements[3], 4)
	testing.expect_value(t, info.playable_width, 32)
	testing.expect_value(t, info.playable_height, 24)
	testing.expect_value(t, info.flags, 0x1234)
	testing.expect_value(t, info.tileset, 'L')
	testing.expect_value(t, info.loading_screen_text, "Loading Text")
	testing.expect_value(t, info.loading_screen_title, "Loading Title")
	testing.expect_value(t, info.loading_screen_subtitle, "Loading Subtitle")
	testing.expect_value(t, info.prologue_screen_text, "Prologue Text")
	testing.expect_value(t, info.prologue_screen_title, "Prologue Title")
	testing.expect_value(t, info.prologue_screen_subtitle, "Prologue Subtitle")

	testing.expect_value(t, len(info.players), 1)
	player := info.players[0]
	testing.expect_value(t, player.id, 0)
	testing.expect_value(t, player.controller, 1)
	testing.expect_value(t, player.race, 2)
	testing.expect_value(t, player.flags, 1)
	testing.expect_value(t, player.name, "TRIGSTR_000")
	testing.expect_value(t, player.start_x, -512)
	testing.expect_value(t, player.start_y, 256)
	testing.expect_value(t, player.ally_low_priorities, 0)
	testing.expect_value(t, player.ally_high_priorities, 2)

	testing.expect_value(t, len(info.forces), 1)
	testing.expect_value(t, info.forces[0].flags, 0)
	testing.expect_value(t, info.forces[0].players, 0xFFFF_FFFF)
	testing.expect_value(t, info.forces[0].name, "Force 1")

	testing.expect_value(t, len(info.upgrades), 1)
	testing.expect_value(t, info.upgrades[0].players, 0xFF)
	testing.expect_value(t, info.upgrades[0].id, [4]u8{'R', 'h', 'm', 'e'})
	testing.expect_value(t, info.upgrades[0].level, 2)
	testing.expect_value(t, info.upgrades[0].availability, 1)

	testing.expect_value(t, len(info.techs), 1)
	testing.expect_value(t, info.techs[0].players, 1)
	testing.expect_value(t, info.techs[0].id, [4]u8{'h', 'f', 'o', 'o'})

	testing.expect_value(t, len(info.random_unit_tables), 1)
	table := info.random_unit_tables[0]
	testing.expect_value(t, table.index, 0)
	testing.expect_value(t, table.name, "Unit Table")
	testing.expect_value(t, len(table.widget_types), 2)
	testing.expect_value(t, table.widget_types[0], 0)
	testing.expect_value(t, table.widget_types[1], 2)
	testing.expect_value(t, len(table.lines), 1)
	testing.expect_value(t, table.lines[0].chance, 50)
	testing.expect_value(t, table.lines[0].unit_ids[0], [4]u8{'h', 'f', 'o', 'o'})
	testing.expect_value(t, table.lines[0].unit_ids[1], [4]u8{'h', 'p', 'e', 'a'})
}

@(test)
v18_file_decodes :: proc(t: ^testing.T) {
	file := test_build_v18_file()
	defer delete(file)
	info, error := parse(file[:])
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.version, u32(VERSION_REIGN_OF_CHAOS))
	testing.expect_value(t, info.campaign_background_number, -1)
	testing.expect_value(t, info.loading_screen_number, -1)
	testing.expect_value(t, info.tail_skipped, false)
	testing.expect_value(t, len(info.random_item_tables), 0)
	test_expect_common_fields(t, &info)
}

@(test)
v25_file_decodes :: proc(t: ^testing.T) {
	file := test_build_v25_file()
	defer delete(file)
	info, error := parse(file[:])
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.version, u32(VERSION_FROZEN_THRONE))
	testing.expect_value(t, info.loading_screen_background_number, -1)
	testing.expect_value(t, info.loading_screen_path, "LoadingScreen.mdx")
	testing.expect_value(t, info.game_data_set, 0)
	testing.expect_value(t, info.prologue_screen_path, "Prologue.mdx")
	testing.expect_value(t, info.fog_style, 0)
	testing.expect_value(t, info.fog_start_z, 3000)
	testing.expect_value(t, info.fog_end_z, 5000)
	testing.expect_value(t, info.fog_density, 0.5)
	testing.expect_value(t, info.fog_color, [4]u8{0, 0, 0, 255})
	testing.expect_value(t, info.global_weather_id, [4]u8{'R', 'A', 'h', 'r'})
	testing.expect_value(t, info.sound_environment, "LakeEverGreenDay")
	testing.expect_value(t, info.light_environment, 'D')
	testing.expect_value(t, info.water_tint, [4]u8{255, 255, 255, 255})
	test_expect_common_fields(t, &info)

	testing.expect_value(t, len(info.random_item_tables), 1)
	table := info.random_item_tables[0]
	testing.expect_value(t, table.index, 0)
	testing.expect_value(t, table.name, "Item Table")
	testing.expect_value(t, len(table.item_sets), 1)
	testing.expect_value(t, len(table.item_sets[0].items), 2)
	testing.expect_value(t, table.item_sets[0].items[0].chance, 30)
	testing.expect_value(t, table.item_sets[0].items[0].id, [4]u8{'r', 'a', 't', 'c'})
	testing.expect_value(t, table.item_sets[0].items[1].chance, 70)
	testing.expect_value(t, table.item_sets[0].items[1].id, [4]u8{'r', 'd', 'e', '1'})
}

@(test)
unsupported_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_v25_file()
	defer delete(file)
	file[0] = 28
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
	empty: []u8
	_, empty_error := parse(empty)
	testing.expect_value(t, empty_error, Error.Truncated)
}

// Every truncation point must produce an error, never a crash or a
// leak (the test runner tracks memory).
@(test)
all_truncations_error_cleanly :: proc(t: ^testing.T) {
	file := test_build_v25_file()
	defer delete(file)
	for length in 4 ..< len(file) {
		info, error := parse(file[:length])
		if error == .None {
			// The mirrored quirk: ending right after the upgrade
			// list is a valid file.
			testing.expect_value(t, len(info.techs), 0)
			destroy(&info)
		}
	}
}

// A name string running to the end of the buffer without a NUL.
@(test)
unterminated_string_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_u32(&file, VERSION_REIGN_OF_CHAOS)
	test_append_i32(&file, 7)
	test_append_i32(&file, 6030)
	append(&file, "An Unterminated Name")
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unterminated_String)
}

// A player count far larger than the remaining bytes must fail before
// the allocation.
@(test)
oversized_player_count_is_rejected :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_common_header(&file, VERSION_REIGN_OF_CHAOS)
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_u32(&file, 0x7FFF_FFFF)
	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// The 0xFF marker in place of the upgrade count skips the rest.
@(test)
skip_marker_after_forces_is_accepted :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_common_header(&file, VERSION_REIGN_OF_CHAOS)
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	append(&file, 0xFF)
	append(&file, "garbage after the marker")
	info, error := parse(file[:])
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.tail_skipped, true)
	testing.expect_value(t, len(info.upgrades), 0)
}

// The file may end right after the upgrade list (mirrored War3Net
// quirk).
@(test)
end_after_upgrades_is_accepted :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_common_header(&file, VERSION_REIGN_OF_CHAOS)
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_i32(&file, -1)
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_string(&file, "")
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	test_append_u32(&file, 0)
	info, error := parse(file[:])
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.tail_skipped, false)
	testing.expect_value(t, len(info.upgrades), 0)
	testing.expect_value(t, len(info.techs), 0)
}
