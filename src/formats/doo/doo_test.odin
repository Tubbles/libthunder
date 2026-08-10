package doo

// Synthetic-fixture tests: hand-built placement byte streams for both
// files and both supported version pairs, no game data.

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
test_append_i24 :: proc(buffer: ^[dynamic]u8, value: i32) {
	raw := u32(value)
	append(buffer, u8(raw), u8(raw >> 8), u8(raw >> 16))
}

@(private)
test_append_vector3 :: proc(buffer: ^[dynamic]u8, value: [3]f32) {
	for component in value {
		test_append_f32(buffer, component)
	}
}

@(private)
test_append_header :: proc(file: ^[dynamic]u8, version: i32, sub_version: i32, count: i32) {
	append(file, MAGIC)
	test_append_i32(file, version)
	test_append_i32(file, sub_version)
	test_append_i32(file, count)
}

// Type id through the scale triple, identical in both files.
@(private)
test_append_widget_head :: proc(
	file: ^[dynamic]u8,
	type_id: string,
	variation: i32,
	position: [3]f32,
	rotation: f32,
	scale: [3]f32,
) {
	append(file, type_id)
	test_append_i32(file, variation)
	test_append_vector3(file, position)
	test_append_f32(file, rotation)
	test_append_vector3(file, scale)
}

@(private)
test_append_item_set :: proc(file: ^[dynamic]u8, items: [][4]u8, chances: []i32) {
	test_append_i32(file, i32(len(items)))
	for item, index in items {
		append(file, item[0], item[1], item[2], item[3])
		test_append_i32(file, chances[index])
	}
}

// A start location: every counted list empty, random mode 0.
@(private)
test_append_minimal_unit :: proc(file: ^[dynamic]u8, version: i32) {
	test_append_widget_head(file, "sloc", 0, {-1024, 512, 64}, 4.71238899, {1, 1, 1})
	append(file, u8(2))
	test_append_i32(file, 0)
	append(file, u8(0), u8(0))
	test_append_i32(file, 0)
	test_append_i32(file, 0)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, NO_ITEM_TABLE)
	}
	test_append_i32(file, 0) // no drop sets
	test_append_i32(file, 0) // gold
	test_append_f32(file, 0)
	test_append_i32(file, 0) // hero level
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, 0)
		test_append_i32(file, 0)
		test_append_i32(file, 0)
	}
	test_append_i32(file, 0) // no inventory
	test_append_i32(file, 0) // no modified abilities
	test_append_i32(file, RANDOM_MODE_ANY)
	test_append_i24(file, -1)
	append(file, u8(0))
	test_append_i32(file, -1) // custom color
	test_append_i32(file, -1) // waygate
	test_append_i32(file, 17)
}

// A creep carrying every optional list: two drop sets, two inventory
// items, two modified abilities and an inline random-unit table.
@(private)
test_append_rich_unit :: proc(file: ^[dynamic]u8, version: i32) {
	test_append_widget_head(file, "nskf", 1, {451.5, -4572.25, 0}, 5.65504169, {1, 1, 2})
	append(file, u8(3))
	test_append_i32(file, 11)
	append(file, u8(0), u8(0))
	test_append_i32(file, -1)
	test_append_i32(file, -1)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, 3)
	}
	test_append_i32(file, 2) // two drop sets
	test_append_item_set(file, {{'Y', 'Y', 'I', '4'}, {'r', 'a', 't', 'c'}}, {100, 30})
	test_append_item_set(file, {{'r', 'd', 'e', '1'}}, {70})
	test_append_i32(file, 12500)
	test_append_f32(file, -1)
	test_append_i32(file, 3) // hero level
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, 10)
		test_append_i32(file, 20)
		test_append_i32(file, 30)
	}
	test_append_i32(file, 2) // inventory
	test_append_i32(file, 0)
	append(file, "ratc")
	test_append_i32(file, 5)
	append(file, "rde1")
	test_append_i32(file, 2) // modified abilities
	append(file, "ACbl")
	test_append_i32(file, 1)
	test_append_i32(file, 0)
	append(file, "AInv")
	test_append_i32(file, 0)
	test_append_i32(file, 2)
	test_append_i32(file, RANDOM_MODE_CUSTOM_TABLE)
	test_append_i32(file, 2)
	append(file, "nmoo")
	test_append_i32(file, 50)
	append(file, "nfoh")
	test_append_i32(file, 50)
	test_append_i32(file, 4) // custom color
	test_append_i32(file, 39) // waygate destination
	test_append_i32(file, 46)
}

// Random mode 1 (a column of a war3map.w3i random unit table).
@(private)
test_append_global_table_unit :: proc(file: ^[dynamic]u8, version: i32) {
	test_append_widget_head(file, "ngol", 0, {0, 0, 0}, 0, {1, 1, 1})
	append(file, u8(2))
	test_append_i32(file, 12)
	append(file, u8(0), u8(0))
	test_append_i32(file, -1)
	test_append_i32(file, -1)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, NO_ITEM_TABLE)
	}
	test_append_i32(file, 0)
	test_append_i32(file, 20000)
	test_append_f32(file, -1)
	test_append_i32(file, 1)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, 0)
		test_append_i32(file, 0)
		test_append_i32(file, 0)
	}
	test_append_i32(file, 0)
	test_append_i32(file, 0)
	test_append_i32(file, RANDOM_MODE_GLOBAL_TABLE)
	test_append_i32(file, 6)
	test_append_i32(file, 2)
	test_append_i32(file, -1)
	test_append_i32(file, -1)
	test_append_i32(file, 1)
}

// The corpus quirk: a mode value outside 0..2 carries no payload.
@(private)
test_append_no_random_unit :: proc(file: ^[dynamic]u8, version: i32) {
	test_append_widget_head(file, "ncp2", 0, {-928, 6432, 384}, 4.71238899, {1, 1, 1})
	append(file, u8(2))
	test_append_i32(file, 15)
	append(file, u8(0), u8(0))
	test_append_i32(file, -1)
	test_append_i32(file, -1)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, NO_ITEM_TABLE)
	}
	test_append_i32(file, 0)
	test_append_i32(file, 12500)
	test_append_f32(file, -1)
	test_append_i32(file, 1)
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(file, 0)
		test_append_i32(file, 0)
		test_append_i32(file, 0)
	}
	test_append_i32(file, 0)
	test_append_i32(file, 0)
	test_append_i32(file, 641) // observed in (4)Roundabout.w3x
	test_append_i32(file, -1)
	test_append_i32(file, -1)
	test_append_i32(file, 79)
}

@(private)
test_build_units_file :: proc(version: i32, sub_version: i32) -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_header(&file, version, sub_version, 4)
	test_append_minimal_unit(&file, version)
	test_append_rich_unit(&file, version)
	test_append_global_table_unit(&file, version)
	test_append_no_random_unit(&file, version)
	return file
}

@(private)
test_build_doodads_file :: proc(version: i32, sub_version: i32) -> [dynamic]u8 {
	file := make([dynamic]u8)
	test_append_header(&file, version, sub_version, 3)

	test_append_widget_head(&file, "YOst", 0, {-8448, -7872, 128}, 0.00761863217, {0.95, 0.95, 0.95})
	append(&file, u8(2), u8(255))
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(&file, NO_ITEM_TABLE)
		test_append_i32(&file, 0)
	}
	test_append_i32(&file, 0)

	// A destructable that drops items on death: two sets in v8, none in
	// v7, which has no drop data at all.
	test_append_widget_head(&file, "LTlt", 2, {-8224, -5472, 0}, 1.74532938, {0.9, 0.9, 1})
	append(&file, u8(3), u8(100))
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(&file, NO_ITEM_TABLE)
		test_append_i32(&file, 2)
		test_append_item_set(&file, {{'r', 'a', 't', 'c'}, {'r', 'd', 'e', '1'}}, {60, 40})
		test_append_item_set(&file, {{'Y', 'Y', 'I', '2'}}, {100})
	}
	test_append_i32(&file, 415)

	// A destructable pointing at a war3map.w3i item table instead.
	test_append_widget_head(&file, "ITtw", 1, {-3579.5, 3072.25, 0}, 6.14355946, {1, 1, 1.125})
	append(&file, u8(6), u8(40))
	if version == VERSION_FROZEN_THRONE {
		test_append_i32(&file, 7)
		test_append_i32(&file, 0)
	}
	test_append_i32(&file, 830)

	test_append_i32(&file, SPECIAL_DOODAD_VERSION)
	test_append_i32(&file, 2)
	append(&file, "YCx1")
	test_append_i32(&file, 0)
	test_append_i32(&file, 42)
	test_append_i32(&file, 36)
	append(&file, "YCx4")
	test_append_i32(&file, 0)
	test_append_i32(&file, 38)
	test_append_i32(&file, 39)
	return file
}

@(private)
test_expect_units :: proc(t: ^testing.T, placed: Placed_Units, version: i32) {
	is_frozen_throne := version == VERSION_FROZEN_THRONE
	testing.expect_value(t, len(placed.units), 4)
	if len(placed.units) != 4 {
		return
	}

	minimal := placed.units[0]
	testing.expect_value(t, minimal.type_id, [4]u8{'s', 'l', 'o', 'c'})
	testing.expect_value(t, minimal.position, [3]f32{-1024, 512, 64})
	testing.expect_value(t, minimal.scale, [3]f32{1, 1, 1})
	testing.expect_value(t, minimal.flags, 2)
	testing.expect_value(t, minimal.owning_player, 0)
	testing.expect_value(t, minimal.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, len(minimal.dropped_item_sets), 0)
	testing.expect_value(t, minimal.creation_number, 17)
	random_any, is_any := minimal.random_data.(Random_Any)
	testing.expect(t, is_any, "minimal unit should carry a mode 0 random block")
	testing.expect_value(t, random_any.level, -1)
	testing.expect_value(t, random_any.item_class, 0)

	rich := placed.units[1]
	testing.expect_value(t, rich.type_id, [4]u8{'n', 's', 'k', 'f'})
	testing.expect_value(t, rich.variation, 1)
	testing.expect_value(t, rich.rotation, 5.65504169)
	testing.expect_value(t, rich.scale, [3]f32{1, 1, 2})
	testing.expect_value(t, rich.owning_player, 11)
	testing.expect_value(t, rich.hit_points, -1)
	testing.expect_value(t, rich.mana_points, -1)
	testing.expect_value(t, rich.item_table_id, is_frozen_throne ? 3 : NO_ITEM_TABLE)
	testing.expect_value(t, len(rich.dropped_item_sets), 2)
	testing.expect_value(t, len(rich.dropped_item_sets[0].items), 2)
	testing.expect_value(t, rich.dropped_item_sets[0].items[0].id, [4]u8{'Y', 'Y', 'I', '4'})
	testing.expect_value(t, rich.dropped_item_sets[0].items[0].chance, 100)
	testing.expect_value(t, rich.dropped_item_sets[0].items[1].id, [4]u8{'r', 'a', 't', 'c'})
	testing.expect_value(t, rich.dropped_item_sets[1].items[0].chance, 70)
	testing.expect_value(t, rich.gold_amount, 12500)
	testing.expect_value(t, rich.target_acquisition, -1)
	testing.expect_value(t, rich.hero_level, 3)
	testing.expect_value(t, rich.hero_strength, is_frozen_throne ? 10 : 0)
	testing.expect_value(t, rich.hero_agility, is_frozen_throne ? 20 : 0)
	testing.expect_value(t, rich.hero_intelligence, is_frozen_throne ? 30 : 0)
	testing.expect_value(t, len(rich.inventory), 2)
	testing.expect_value(t, rich.inventory[0].slot, 0)
	testing.expect_value(t, rich.inventory[0].id, [4]u8{'r', 'a', 't', 'c'})
	testing.expect_value(t, rich.inventory[1].slot, 5)
	testing.expect_value(t, len(rich.modified_abilities), 2)
	testing.expect_value(t, rich.modified_abilities[0].id, [4]u8{'A', 'C', 'b', 'l'})
	testing.expect_value(t, rich.modified_abilities[0].autocast_active, 1)
	testing.expect_value(t, rich.modified_abilities[1].level, 2)
	custom_table, is_custom_table := rich.random_data.(Random_Custom_Table)
	testing.expect(t, is_custom_table, "rich unit should carry a mode 2 random block")
	testing.expect_value(t, len(custom_table.choices), 2)
	testing.expect_value(t, custom_table.choices[0].id, [4]u8{'n', 'm', 'o', 'o'})
	testing.expect_value(t, custom_table.choices[1].chance, 50)
	testing.expect_value(t, rich.custom_color, 4)
	testing.expect_value(t, rich.waygate_destination, 39)

	global := placed.units[2]
	global_table, is_global_table := global.random_data.(Random_Global_Table)
	testing.expect(t, is_global_table, "third unit should carry a mode 1 random block")
	testing.expect_value(t, global_table.table_id, 6)
	testing.expect_value(t, global_table.column, 2)
	testing.expect_value(t, global.gold_amount, 20000)

	no_random := placed.units[3]
	testing.expect_value(t, no_random.random_mode, 641)
	testing.expect(t, no_random.random_data == nil, "an unknown random mode carries no payload")
	testing.expect_value(t, no_random.creation_number, 79)
}

@(private)
test_expect_doodads :: proc(t: ^testing.T, placed: Placed_Doodads, version: i32) {
	is_frozen_throne := version == VERSION_FROZEN_THRONE
	testing.expect_value(t, len(placed.doodads), 3)
	if len(placed.doodads) != 3 {
		return
	}

	tree := placed.doodads[0]
	testing.expect_value(t, tree.type_id, [4]u8{'Y', 'O', 's', 't'})
	testing.expect_value(t, tree.variation, 0)
	testing.expect_value(t, tree.position, [3]f32{-8448, -7872, 128})
	testing.expect_value(t, tree.rotation, 0.00761863217)
	testing.expect_value(t, tree.scale, [3]f32{0.95, 0.95, 0.95})
	testing.expect_value(t, tree.flags, 2)
	testing.expect_value(t, tree.life_percentage, 255)
	testing.expect_value(t, tree.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, tree.creation_number, 0)

	dropper := placed.doodads[1]
	testing.expect_value(t, dropper.type_id, [4]u8{'L', 'T', 'l', 't'})
	testing.expect_value(t, dropper.variation, 2)
	testing.expect_value(t, dropper.flags, 3)
	testing.expect_value(t, dropper.life_percentage, 100)
	testing.expect_value(t, dropper.creation_number, 415)
	testing.expect_value(t, len(dropper.dropped_item_sets), is_frozen_throne ? 2 : 0)
	if is_frozen_throne {
		testing.expect_value(t, len(dropper.dropped_item_sets[0].items), 2)
		testing.expect_value(t, dropper.dropped_item_sets[0].items[0].id, [4]u8{'r', 'a', 't', 'c'})
		testing.expect_value(t, dropper.dropped_item_sets[0].items[0].chance, 60)
		testing.expect_value(t, dropper.dropped_item_sets[1].items[0].id, [4]u8{'Y', 'Y', 'I', '2'})
	}

	tabled := placed.doodads[2]
	testing.expect_value(t, tabled.life_percentage, 40)
	testing.expect_value(t, tabled.item_table_id, is_frozen_throne ? 7 : NO_ITEM_TABLE)
	testing.expect_value(t, len(tabled.dropped_item_sets), 0)
	testing.expect_value(t, tabled.creation_number, 830)

	testing.expect_value(t, placed.special_doodad_version, SPECIAL_DOODAD_VERSION)
	testing.expect_value(t, len(placed.special_doodads), 2)
	if len(placed.special_doodads) != 2 {
		return
	}
	testing.expect_value(t, placed.special_doodads[0].type_id, [4]u8{'Y', 'C', 'x', '1'})
	testing.expect_value(t, placed.special_doodads[0].variation, 0)
	testing.expect_value(t, placed.special_doodads[0].grid_x, 42)
	testing.expect_value(t, placed.special_doodads[0].grid_y, 36)
	testing.expect_value(t, placed.special_doodads[1].type_id, [4]u8{'Y', 'C', 'x', '4'})
	testing.expect_value(t, placed.special_doodads[1].grid_y, 39)
}

@(test)
reign_of_chaos_units_decode :: proc(t: ^testing.T) {
	file := test_build_units_file(VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS)
	defer delete(file)
	placed, error := parse_units(file[:])
	defer destroy(&placed)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, placed.version, VERSION_REIGN_OF_CHAOS)
	testing.expect_value(t, placed.sub_version, SUB_VERSION_REIGN_OF_CHAOS)
	test_expect_units(t, placed, VERSION_REIGN_OF_CHAOS)
}

@(test)
frozen_throne_units_decode :: proc(t: ^testing.T) {
	file := test_build_units_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(file)
	placed, error := parse_units(file[:])
	defer destroy(&placed)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, placed.version, VERSION_FROZEN_THRONE)
	testing.expect_value(t, placed.sub_version, SUB_VERSION_FROZEN_THRONE)
	test_expect_units(t, placed, VERSION_FROZEN_THRONE)
}

@(test)
reign_of_chaos_doodads_decode :: proc(t: ^testing.T) {
	file := test_build_doodads_file(VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS)
	defer delete(file)
	placed, error := parse_doodads(file[:])
	defer destroy(&placed)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, placed.version, VERSION_REIGN_OF_CHAOS)
	test_expect_doodads(t, placed, VERSION_REIGN_OF_CHAOS)
}

@(test)
frozen_throne_doodads_decode :: proc(t: ^testing.T) {
	file := test_build_doodads_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(file)
	placed, error := parse_doodads(file[:])
	defer destroy(&placed)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, placed.version, VERSION_FROZEN_THRONE)
	test_expect_doodads(t, placed, VERSION_FROZEN_THRONE)
}

// Every truncation point must produce an error, never a crash or a
// leak (the test runner tracks memory). Nothing shorter than the whole
// file can parse: every list is counted and the parse must land on
// exact end of file.
@(test)
all_units_truncations_error_cleanly :: proc(t: ^testing.T) {
	versions := [?][2]i32 {
		{VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS},
		{VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE},
	}
	for version_pair in versions {
		file := test_build_units_file(version_pair[0], version_pair[1])
		defer delete(file)
		for length in 0 ..< len(file) {
			placed, error := parse_units(file[:length])
			testing.expectf(t, error != .None, "prefix of %d bytes parsed", length)
			destroy(&placed)
		}
	}
}

@(test)
all_doodads_truncations_error_cleanly :: proc(t: ^testing.T) {
	versions := [?][2]i32 {
		{VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS},
		{VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE},
	}
	for version_pair in versions {
		file := test_build_doodads_file(version_pair[0], version_pair[1])
		defer delete(file)
		for length in 0 ..< len(file) {
			placed, error := parse_doodads(file[:length])
			testing.expectf(t, error != .None, "prefix of %d bytes parsed", length)
			destroy(&placed)
		}
	}
}

@(test)
bad_magic_is_rejected :: proc(t: ^testing.T) {
	units := test_build_units_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(units)
	units[3] = 'D'
	_, units_error := parse_units(units[:])
	testing.expect_value(t, units_error, Error.Bad_Magic)

	doodads := test_build_doodads_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(doodads)
	doodads[0] = 'w'
	_, doodads_error := parse_doodads(doodads[:])
	testing.expect_value(t, doodads_error, Error.Bad_Magic)

	empty: []u8
	_, empty_error := parse_units(empty)
	testing.expect_value(t, empty_error, Error.Truncated)
}

// Only the two corpus version pairs are accepted; a mismatched pair is
// as unsupported as an unknown version.
@(test)
unsupported_versions_are_rejected :: proc(t: ^testing.T) {
	rejected := [?][2]i32{{6, 9}, {7, 7}, {7, 11}, {8, 9}, {8, 10}, {9, 11}, {0, 0}}
	for version_pair in rejected {
		units := test_build_units_file(version_pair[0], version_pair[1])
		defer delete(units)
		_, units_error := parse_units(units[:])
		testing.expectf(
			t,
			units_error == .Unsupported_Version,
			"units version %v gave %v",
			version_pair,
			units_error,
		)

		doodads := test_build_doodads_file(version_pair[0], version_pair[1])
		defer delete(doodads)
		_, doodads_error := parse_doodads(doodads[:])
		testing.expectf(
			t,
			doodads_error == .Unsupported_Version,
			"doodads version %v gave %v",
			version_pair,
			doodads_error,
		)
	}
}

// The special-doodad section carries its own version, which has only
// ever been 0.
@(test)
unsupported_special_doodad_version_is_rejected :: proc(t: ^testing.T) {
	file := test_build_doodads_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(file)
	// The section's version int sits 40 bytes before the end: two
	// special doodads of 16 bytes each, preceded by their count.
	version_offset := len(file) - 40
	file[version_offset] = 1
	_, error := parse_doodads(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

@(test)
trailing_bytes_are_rejected :: proc(t: ^testing.T) {
	units := test_build_units_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(units)
	append(&units, u8(0))
	_, units_error := parse_units(units[:])
	testing.expect_value(t, units_error, Error.Trailing_Bytes)

	doodads := test_build_doodads_file(VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS)
	defer delete(doodads)
	append(&doodads, u8(0), u8(0), u8(0), u8(0))
	_, doodads_error := parse_doodads(doodads[:])
	testing.expect_value(t, doodads_error, Error.Trailing_Bytes)
}

// A Reforged-era file adds a skin id after the scale triple without
// bumping any version. The heuristic that detects it is deliberately
// not implemented, so such a file must fail rather than mis-parse.
@(test)
reforged_skin_id_fails_cleanly :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_header(&file, VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE, 1)
	test_append_widget_head(&file, "hfoo", 0, {0, 0, 0}, 0, {1, 1, 1})
	append(&file, "hfoo") // the skin id this reader does not know about
	body := test_build_units_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(body)
	// Everything after the first unit's scale triple, so the entry is
	// well formed apart from the extra four bytes: the 16-byte file
	// header plus a 36-byte widget head, up to the end of that unit
	// (the fixed v8 part plus its four-byte random block).
	append(&file, ..body[16 + 36:16 + UNIT_MINIMUM_SIZE_FROZEN_THRONE + 4])
	placed, error := parse_units(file[:])
	defer destroy(&placed)
	testing.expect(t, error != .None, "a file carrying a skin id must not parse")
}

// The two files share the magic and the version pair, so nothing but
// the entry layout distinguishes them. Feeding one to the other's
// parser must fail rather than produce nonsense.
@(test)
the_two_files_do_not_parse_as_each_other :: proc(t: ^testing.T) {
	units := test_build_units_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(units)
	as_doodads, as_doodads_error := parse_doodads(units[:])
	defer destroy(&as_doodads)
	testing.expect(t, as_doodads_error != .None, "a units file must not parse as doodads")

	doodads := test_build_doodads_file(VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE)
	defer delete(doodads)
	as_units, as_units_error := parse_units(doodads[:])
	defer destroy(&as_units)
	testing.expect(t, as_units_error != .None, "a doodads file must not parse as units")
}

@(test)
oversized_counts_are_rejected :: proc(t: ^testing.T) {
	units := make([dynamic]u8)
	defer delete(units)
	test_append_header(&units, VERSION_FROZEN_THRONE, SUB_VERSION_FROZEN_THRONE, 1000)
	_, units_error := parse_units(units[:])
	testing.expect_value(t, units_error, Error.Invalid_Count)

	doodads := make([dynamic]u8)
	defer delete(doodads)
	test_append_header(&doodads, VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS, 1000)
	_, doodads_error := parse_doodads(doodads[:])
	testing.expect_value(t, doodads_error, Error.Invalid_Count)

	// A per-entry list count, checked the same way.
	inventory := make([dynamic]u8)
	defer delete(inventory)
	test_append_header(&inventory, VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS, 1)
	test_append_widget_head(&inventory, "hfoo", 0, {0, 0, 0}, 0, {1, 1, 1})
	append(&inventory, u8(2))
	test_append_i32(&inventory, 0)
	append(&inventory, u8(0), u8(0))
	test_append_i32(&inventory, -1)
	test_append_i32(&inventory, -1)
	test_append_i32(&inventory, 0) // no drop sets
	test_append_i32(&inventory, 0)
	test_append_f32(&inventory, -1)
	test_append_i32(&inventory, 1)
	test_append_i32(&inventory, 1 << 20) // inventory count
	// Padding so the entry itself clears the minimum-size check and the
	// inventory count is what fails.
	for _ in 0 ..< 5 {
		test_append_i32(&inventory, 0)
	}
	_, inventory_error := parse_units(inventory[:])
	testing.expect_value(t, inventory_error, Error.Invalid_Count)
}

// A count whose product with the entry size overflows 32 bits must be
// caught by the i64 validation: 47197443 entries of 91 bytes is
// 4294967313, which truncates to 17 in 32 bits and would sail past a
// 32-bit check against the bytes that follow.
@(test)
count_product_cannot_wrap_past_the_check :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_header(&file, VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS, 47197443)
	for _ in 0 ..< 10 {
		test_append_i32(&file, 0)
	}
	_, error := parse_units(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}

// The doodad path shares read_count with the unit path, but the wrap
// guard deserves its own pin: 102261127 entries of 42 bytes is
// 4294967334, which truncates to 38 in 32 bits.
@(test)
doodad_count_product_cannot_wrap_past_the_check :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	test_append_header(&file, VERSION_REIGN_OF_CHAOS, SUB_VERSION_REIGN_OF_CHAOS, 102261127)
	for _ in 0 ..< 10 {
		test_append_i32(&file, 0)
	}
	_, error := parse_doodads(file[:])
	testing.expect_value(t, error, Error.Invalid_Count)
}
