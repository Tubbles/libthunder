package gamedata

// Synthetic tests: no corpus needed. Every fixture is a hand-written
// SLK or TXT modelled on the shape the WI-0015 survey found in the
// 1.29.2 data, so the rules under test (case sensitivity both ways,
// the data letter mapping, the two level suffix widths, quoted CSV,
// the layering order) are exercised without the archives.

import "core:strconv"
import "core:strings"
import "core:testing"
import object_data "thunder:formats/object_data"

// Builds SYLK content from a row-major grid whose first row is the
// header. Cells that parse as numbers are written bare so the SLK
// reader types them as numbers, the way the stock tables do.
@(private = "file")
build_slk :: proc(rows: [][]string, allocator := context.allocator) -> string {
	columns := 0
	for row in rows {
		columns = max(columns, len(row))
	}
	builder := strings.builder_make(allocator)
	strings.write_string(&builder, "ID;PWXL;N;E\n")
	strings.write_string(&builder, "B;X")
	write_number(&builder, columns)
	strings.write_string(&builder, ";Y")
	write_number(&builder, len(rows))
	strings.write_string(&builder, ";D0\n")
	for row, row_index in rows {
		for cell, column_index in row {
			if len(cell) == 0 {
				continue
			}
			strings.write_string(&builder, "C;Y")
			write_number(&builder, row_index + 1)
			strings.write_string(&builder, ";X")
			write_number(&builder, column_index + 1)
			strings.write_string(&builder, ";K")
			if _, numeric := strconv.parse_f64(cell); numeric {
				strings.write_string(&builder, cell)
			} else {
				strings.write_byte(&builder, '"')
				strings.write_string(&builder, cell)
				strings.write_byte(&builder, '"')
			}
			strings.write_byte(&builder, '\n')
		}
	}
	strings.write_string(&builder, "E\n")
	return strings.to_string(builder)
}

@(private = "file")
write_number :: proc(builder: ^strings.Builder, number: int) {
	digits: [8]u8
	strings.write_string(builder, strconv.write_int(digits[:], i64(number), 10))
}

@(private = "file")
code :: proc(text: string) -> [4]u8 {
	id, _ := rawcode(text)
	return id
}

// A unit metadata file covering the shapes the tests need: an SLK
// backed field, an item-only field in the same file, and profile
// fields with and without element indexes.
@(private = "file")
UNIT_METADATA :: [][]string {
	{"ID", "field", "slk", "index", "type", "useUnit", "useHero", "useBuilding", "useItem"},
	{"uhpm", "HP", "UnitBalance", "-1", "int", "1", "1", "1", "0"},
	{"unam", "Name", "Profile", "0", "string", "1", "1", "1", "0"},
	{"uico", "Art", "Profile", "0", "icon", "1", "1", "1", "0"},
	{"iico", "Art", "Profile", "0", "icon", "0", "0", "0", "1"},
	{"ubpx", "Buttonpos", "Profile", "0", "int", "1", "1", "1", "1"},
	{"ubpy", "Buttonpos", "Profile", "1", "int", "1", "1", "1", "1"},
	{"utip", "Tip", "Profile", "0", "string", "1", "1", "1", "0"},
	{"igol", "goldcost", "ItemData", "-1", "int", "0", "0", "0", "1"},
	{"iabi", "abilList", "ItemData", "-1", "abilityList", "0", "0", "0", "1"},
}

// Ability metadata, where the DataX family and the useSpecific gating
// live. `Igol` is the real lowercase collision partner of the unit
// file's `igol`, and `Crs` is the one three-character id.
@(private = "file")
ABILITY_METADATA :: [][]string {
	{"ID", "field", "slk", "index", "repeat", "data", "type", "useSpecific", "notSpecific"},
	{"aher", "hero", "AbilityData", "0", "0", "0", "bool", "", ""},
	{"acas", "Cast", "AbilityData", "-1", "4", "0", "unreal", "", "Arpb"},
	{"Rpb6", "Cast", "AbilityData", "-1", "4", "0", "unreal", "Arpb", ""},
	{"Igol", "Data", "AbilityData", "-1", "4", "1", "unreal", "AIlb", ""},
	{"fbk5", "Data", "AbilityData", "-1", "4", "5", "unreal", "Afbt", ""},
	{"Crs", "Data", "AbilityData", "-1", "4", "1", "unreal", "Acrs", ""},
	{"atp1", "Tip", "Profile", "0", "3", "0", "string", "", ""},
	{"anam", "Name", "Profile", "0", "0", "0", "string", "", ""},
}

@(private = "file")
UPGRADE_METADATA :: [][]string {
	{"ID", "field", "slk", "index", "repeat", "appendIndex", "type"},
	{"gnam", "Name", "Profile", "0", "1", "0", "string"},
	{"greq", "Requires", "Profile", "0", "1", "1", "techList"},
	{"grac", "race", "UpgradeData", "-1", "0", "0", "unitRace"},
}

@(private = "file")
DOODAD_METADATA :: [][]string {
	{"ID", "field", "slk", "index", "repeat", "type"},
	{"dvr1", "vertR", "DoodadData", "0", "10", "int"},
	{"dnam", "Name", "DoodadData", "0", "0", "string"},
}

@(private = "file")
load_test_metadata :: proc(t: ^testing.T, database: ^Database) {
	for pair in ([?]struct {
			source: Metadata_Source,
			rows:   [][]string,
		}{
			{.Unit, UNIT_METADATA},
			{.Ability, ABILITY_METADATA},
			{.Upgrade, UPGRADE_METADATA},
			{.Doodad, DOODAD_METADATA},
		}) {
		content := build_slk(pair.rows)
		defer delete(content)
		testing.expect_value(t, load_metadata(database, pair.source, content), Error.None)
	}
}

@(test)
metadata_ids_are_case_sensitive :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	// The eight lowercase collisions in the stock metadata pair an
	// ability Data field with an item or unit field. Folding case
	// would hand out an ability's DataA where an item's gold cost was
	// asked for.
	item_gold, item_found := find_descriptor(&database.metadata, code("igol"))
	testing.expect(t, item_found, "igol missing")
	testing.expect_value(t, item_gold.table, Table.Item_Data)
	testing.expect_value(t, item_gold.field, "goldcost")

	ability_data, ability_found := find_descriptor(&database.metadata, code("Igol"))
	testing.expect(t, ability_found, "Igol missing")
	testing.expect_value(t, ability_data.table, Table.Ability_Data)
	testing.expect_value(t, ability_data.column, "DataA")
}

@(test)
three_character_id_is_nul_padded :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	// The file stores ids in a fixed four-byte field, so the metadata's
	// only three-character id arrives as "Crs\x00".
	descriptor, found := find_descriptor(&database.metadata, [4]u8{'C', 'r', 's', 0})
	testing.expect(t, found, "Crs missing")
	testing.expect_value(t, descriptor.column, "DataA")
	testing.expect_value(t, code("Crs"), [4]u8{'C', 'r', 's', 0})

	_, four_character_found := find_descriptor(&database.metadata, code("Crsx"))
	testing.expect(t, !four_character_found, "Crs must not answer for a four-character id")
}

@(test)
data_pointer_maps_letters_without_skipping :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	// data=5 is DataE, not DataF: ability Afbt's DataE1 is the 20 its
	// stock tooltip quotes. The HiveWE-derived "skipping E" note is
	// wrong.
	descriptor, found := find_descriptor(&database.metadata, code("fbk5"))
	testing.expect(t, found)
	testing.expect_value(t, descriptor.data, 5)
	testing.expect_value(t, descriptor.column, "DataE")

	name := column_name_for_level(descriptor, 1)
	defer delete(name)
	testing.expect_value(t, name, "DataE1")
}

@(test)
level_suffix_widths_are_per_table :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	ability, _ := find_descriptor(&database.metadata, code("acas"))
	ability_name := column_name_for_level(ability, 4)
	defer delete(ability_name)
	testing.expect_value(t, ability_name, "Cast4")

	// Doodads.slk writes two digits: vertR01, not vertR1.
	doodad, _ := find_descriptor(&database.metadata, code("dvr1"))
	doodad_name := column_name_for_level(doodad, 1)
	defer delete(doodad_name)
	testing.expect_value(t, doodad_name, "vertR01")
	tenth := column_name_for_level(doodad, 10)
	defer delete(tenth)
	testing.expect_value(t, tenth, "vertR10")
}

@(test)
base_tables_load_both_level_widths :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	ability_table := build_slk(
		{
			{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4", "DataE1", "DataE2"},
			{"Afbt", "1", "0.5", "1.5", "-", "_", "20", "21"},
			{"", "1", "9", "9", "9", "9", "9", "9"},
		},
	)
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	doodad_table := build_slk({{"doodID", "Name", "vertR01", "vertR02"}, {"DTrl", "Trail", "40", "41"}})
	defer delete(doodad_table)
	testing.expect_value(t, load_table(&database, .Doodad_Data, doodad_table), Error.None)

	cast_time, cast_found := find_real(&database, .Ability, code("Afbt"), code("acas"), 2)
	testing.expect(t, cast_found)
	testing.expect_value(t, cast_time, 1.5)
	data_e, data_e_found := find_integer(&database, .Ability, code("Afbt"), code("fbk5"), 1)
	testing.expect(t, data_e_found)
	testing.expect_value(t, data_e, 20)

	red, red_found := find_integer(&database, .Doodad, code("DTrl"), code("dvr1"), 2)
	testing.expect(t, red_found)
	testing.expect_value(t, red, 41)

	// The blank-key row is skipped, the way AbilityData.slk's four junk
	// rows and AbilityBuffData.slk's 243 empty rows are.
	testing.expect_value(t, len(database.objects[.Ability]), 1)
}

@(test)
unset_placeholders_store_nothing :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	// `-`, `_`, a space-padded ` - ` and a never-written cell all mean
	// "no value" in the stock tables.
	ability_table := build_slk(
		{{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4"}, {"Acrs", "-", "_", " - ", "", "3"}},
	)
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	_, hero_found := find_value(&database, .Ability, code("Acrs"), code("aher"))
	testing.expect(t, !hero_found, "`-` must not store a value")
	for level in 1 ..= 3 {
		_, found := find_value(&database, .Ability, code("Acrs"), code("acas"), level)
		testing.expect(t, !found, "placeholder or missing cell must not store a value")
	}
	cast_time, cast_found := find_integer(&database, .Ability, code("Acrs"), code("acas"), 4)
	testing.expect(t, cast_found)
	testing.expect_value(t, cast_time, 3)
}

@(test)
use_specific_gates_which_objects_carry_a_field :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	ability_table := build_slk(
		{
			{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4", "DataA1", "DataA2", "DataA3", "DataA4"},
			{"Arpb", "0", "1", "1", "1", "1", "5", "5", "5", "5"},
			{"AIlb", "0", "2", "2", "2", "2", "7", "7", "7", "7"},
		},
	)
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	// Cast is declared twice: generically as `acas`, which excludes
	// Arpb, and specifically as `Rpb6` for Arpb alone. Each ability
	// ends up with exactly one of them.
	_, generic_on_excluded := find_value(&database, .Ability, code("Arpb"), code("acas"), 1)
	testing.expect(t, !generic_on_excluded, "notSpecific must exclude the generic field")
	specific, specific_found := find_integer(&database, .Ability, code("Arpb"), code("Rpb6"), 1)
	testing.expect(t, specific_found)
	testing.expect_value(t, specific, 1)

	_, specific_elsewhere := find_value(&database, .Ability, code("AIlb"), code("Rpb6"), 1)
	testing.expect(t, !specific_elsewhere, "useSpecific must not leak to other abilities")
	generic, generic_found := find_integer(&database, .Ability, code("AIlb"), code("acas"), 1)
	testing.expect(t, generic_found)
	testing.expect_value(t, generic, 2)

	// `Igol` is declared for AIlb only, so Arpb never carries it even
	// though both abilities have a DataA1 cell.
	data_a, data_a_found := find_integer(&database, .Ability, code("AIlb"), code("Igol"), 1)
	testing.expect(t, data_a_found)
	testing.expect_value(t, data_a, 7)
	_, wrong_ability := find_value(&database, .Ability, code("Arpb"), code("Igol"), 1)
	testing.expect(t, !wrong_ability)
}

@(test)
level_resolution_is_explicit :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	ability_table := build_slk(
		{{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4"}, {"Acrs", "1", "10", "20", "30", "40"}},
	)
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	// Levels the table stores answer exactly.
	value, found := find_integer(&database, .Ability, code("Acrs"), code("acas"), 3)
	testing.expect(t, found)
	testing.expect_value(t, value, 30)

	// Object data reaches levels past the four the table stores; the
	// corpus has abilities at level 15.
	modifications := [?]object_data.Modification {
		{id = code("acas"), value_type = .Integer, level = 7, value = i32(70)},
	}
	entries := [?]object_data.Entry{{old_id = code("Acrs"), modifications = modifications[:]}}
	data := object_data.Object_Data {
		original = entries[:],
	}
	testing.expect_value(t, apply_object_data(&database, &data, .Ability), Error.None)

	value, found = find_integer(&database, .Ability, code("Acrs"), code("acas"), 7)
	testing.expect(t, found)
	testing.expect_value(t, value, 70)

	// Levels nothing was written for miss rather than clamping to the
	// nearest stored level.
	_, out_of_range := find_value(&database, .Ability, code("Acrs"), code("acas"), 6)
	testing.expect(t, !out_of_range, "an unwritten level must miss, not clamp")
	_, negative := find_value(&database, .Ability, code("Acrs"), code("acas"), -1)
	testing.expect(t, !negative)

	// Level 0 on a leveled field falls back to level 1, which is what
	// asking a leveled field without a level means.
	value, found = find_integer(&database, .Ability, code("Acrs"), code("acas"), 0)
	testing.expect(t, found)
	testing.expect_value(t, value, 10)

	// A modification that states level 0 on a leveled field (six
	// corpus cases) is stored where the file put it, in the unleveled
	// slot, from where it answers for every level the file left empty.
	zero_level := [?]object_data.Modification {
		{id = code("acas"), value_type = .Integer, level = 0, value = i32(99)},
	}
	zero_entries := [?]object_data.Entry{{old_id = code("Acrs"), modifications = zero_level[:]}}
	zero_data := object_data.Object_Data {
		original = zero_entries[:],
	}
	testing.expect_value(t, apply_object_data(&database, &zero_data, .Ability), Error.None)
	value, found = find_integer(&database, .Ability, code("Acrs"), code("acas"), 6)
	testing.expect(t, found)
	testing.expect_value(t, value, 99)
	value, found = find_integer(&database, .Ability, code("Acrs"), code("acas"), 3)
	testing.expect(t, found)
	testing.expect_value(t, value, 30)
}

@(test)
absurd_levels_are_dropped_not_allocated :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	modifications := [?]object_data.Modification {
		{id = code("acas"), value_type = .Integer, level = 1 << 30, value = i32(1)},
		{id = code("acas"), value_type = .String, level = 1 << 30, value = "text"},
	}
	entries := [?]object_data.Entry{{old_id = code("Acrs"), modifications = modifications[:]}}
	data := object_data.Object_Data {
		original = entries[:],
	}
	testing.expect_value(t, apply_object_data(&database, &data, .Ability), Error.None)
	testing.expect_value(t, database.stats.modification_level_drops, 2)
	testing.expect_value(t, database.stats.modifications_applied, 0)
}

@(test)
profile_values_decode_as_quoted_csv :: proc(t: ^testing.T) {
	// Quotes protect the commas inside a value; without them, splitting
	// truncates 1145 stock values.
	quoted := `"a,b","c,d"`
	testing.expect_value(t, profile_element_count(quoted), 2)
	first, first_found := profile_element(quoted, 0)
	testing.expect(t, first_found)
	testing.expect_value(t, first, "a,b")
	second, second_found := profile_element(quoted, 1)
	testing.expect(t, second_found)
	testing.expect_value(t, second, "c,d")
	_, third_found := profile_element(quoted, 2)
	testing.expect(t, !third_found)

	// Leading and trailing spaces are part of the value.
	testing.expect_value(t, profile_unquote(" (Spell Breaker)"), " (Spell Breaker)")
	spaced, _ := profile_element(" left , right ", 1)
	testing.expect_value(t, spaced, " right ")

	// A value with no comma is one element, and an empty value is one
	// empty element (`Missileart=`).
	testing.expect_value(t, profile_element_count("single"), 1)
	testing.expect_value(t, profile_element_count(""), 1)
	testing.expect_value(t, profile_element_count("a,"), 2)

	// One layer of quotes comes off, the rest is content.
	testing.expect_value(t, profile_unquote(`"quoted"`), "quoted")
	testing.expect_value(t, profile_unquote(`""quoted""`), `"quoted"`)
	testing.expect_value(t, profile_unquote(`unquoted`), "unquoted")
}

@(test)
profile_txt_keys_are_case_insensitive_and_split_by_metadata :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	unit_table := build_slk({{"unitBalanceID", "HP"}, {"hfoo", "420"}})
	defer delete(unit_table)
	testing.expect_value(t, load_table(&database, .Unit_Balance, unit_table), Error.None)
	item_table := build_slk({{"itemID", "goldcost"}, {"amrc", "100"}})
	defer delete(item_table)
	testing.expect_value(t, load_table(&database, .Item_Data, item_table), Error.None)
	ability_table := build_slk({{"alias", "hero"}, {"AHbz", "0"}})
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	profile := `[hfoo]
NAME=Footman
buttonpos=0,1
art=ReplaceableTextures\CommandButtons\BTNFootman.blp
[amrc]
Art=ReplaceableTextures\CommandButtons\BTNMask.blp
[AHbz]
Tip=Blizzard - [Level 1],Blizzard - [Level 2],Blizzard - [Level 3]
Name="Blizzard, the spell"
`
	testing.expect_value(t, load_profile(&database, profile), Error.None)

	// Metadata field casing and TXT key casing disagree in 26 stock
	// cases, so keys match case insensitively.
	name, name_found := find_text(&database, .Unit, code("hfoo"), code("unam"))
	testing.expect(t, name_found)
	testing.expect_value(t, name, "Footman")

	// A packed value feeds one field per element, chosen by the
	// metadata's index; a field whose siblings never use an index
	// keeps the whole value.
	x_position, x_found := find_integer(&database, .Unit, code("hfoo"), code("ubpx"))
	testing.expect(t, x_found)
	testing.expect_value(t, x_position, 0)
	y_position, y_found := find_integer(&database, .Unit, code("hfoo"), code("ubpy"))
	testing.expect(t, y_found)
	testing.expect_value(t, y_position, 1)

	// `Art` is two different modification ids depending on whether the
	// section names a unit or an item, and the use flags pick.
	unit_icon, unit_icon_found := find_text(&database, .Unit, code("hfoo"), code("uico"))
	testing.expect(t, unit_icon_found)
	testing.expect(t, strings.has_suffix(unit_icon, "BTNFootman.blp"))
	_, item_id_on_unit := find_value(&database, .Unit, code("hfoo"), code("iico"))
	testing.expect(t, !item_id_on_unit, "a unit section must not fill the item field id")
	item_icon, item_icon_found := find_text(&database, .Item, code("amrc"), code("iico"))
	testing.expect(t, item_icon_found)
	testing.expect(t, strings.has_suffix(item_icon, "BTNMask.blp"))

	// A leveled profile field is one key carrying one string per level.
	level_two, level_two_found := find_text(&database, .Ability, code("AHbz"), code("atp1"), 2)
	testing.expect(t, level_two_found)
	testing.expect_value(t, level_two, "Blizzard - [Level 2]")
	testing.expect_value(t, profile_element_count("a,b,c"), 3)

	// A quoted single value keeps its comma and loses its quotes.
	ability_name, ability_name_found := find_text(&database, .Ability, code("AHbz"), code("anam"))
	testing.expect(t, ability_name_found)
	testing.expect_value(t, ability_name, "Blizzard, the spell")
}

@(test)
profile_append_index_keys_carry_levels :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	upgrade_table := build_slk({{"upgradeid", "race"}, {"Rhme", "human"}})
	defer delete(upgrade_table)
	testing.expect_value(t, load_table(&database, .Upgrade_Data, upgrade_table), Error.None)

	// The upgrade metadata spells per-level requirements by appending
	// the level to the key; units use distinct modification ids for
	// the same tiering.
	profile := "[Rhme]\nRequirescount=2\nRequires=\nRequires1=hkee\nRequires2=hcas\n"
	testing.expect_value(t, load_profile(&database, profile), Error.None)

	first, first_found := find_text(&database, .Upgrade, code("Rhme"), code("greq"), 1)
	testing.expect(t, first_found)
	testing.expect_value(t, first, "hkee")
	second, second_found := find_text(&database, .Upgrade, code("Rhme"), code("greq"), 2)
	testing.expect(t, second_found)
	testing.expect_value(t, second, "hcas")
	// `Requirescount` has no metadata row at all in the stock files, so
	// it is counted and dropped rather than guessed at.
	testing.expect_value(t, database.stats.profile_keys_unresolved, 1)
}

@(test)
sections_without_a_base_object_are_skipped :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	// [Misc] and buff codes the SLK tables omit cannot be assigned to
	// an object family, so they are counted and left out.
	profile := "[Misc]\nName=nothing\n[Bdbb]\nName=also nothing\n"
	testing.expect_value(t, load_profile(&database, profile), Error.None)
	testing.expect_value(t, database.stats.profile_sections_skipped, 2)
	testing.expect_value(t, database.stats.profile_values, 0)
}

@(test)
layering_runs_base_then_original_then_custom :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	unit_table := build_slk({{"unitBalanceID", "HP"}, {"hfoo", "420"}})
	defer delete(unit_table)
	testing.expect_value(t, load_table(&database, .Unit_Balance, unit_table), Error.None)
	testing.expect_value(t, load_profile(&database, "[hfoo]\nName=Footman\n"), Error.None)

	health, health_found := find_integer(&database, .Unit, code("hfoo"), code("uhpm"))
	testing.expect(t, health_found)
	testing.expect_value(t, health, 420)

	original_modifications := [?]object_data.Modification {
		{id = code("uhpm"), value_type = .Integer, value = i32(500)},
	}
	custom_modifications := [?]object_data.Modification {
		{id = code("uhpm"), value_type = .Integer, value = i32(700)},
		{id = code("unam"), value_type = .String, value = "Custom Footman"},
	}
	original := [?]object_data.Entry{{old_id = code("hfoo"), modifications = original_modifications[:]}}
	custom := [?]object_data.Entry {
		{old_id = code("hfoo"), new_id = code("x000"), modifications = custom_modifications[:]},
	}
	data := object_data.Object_Data {
		original = original[:],
		custom   = custom[:],
	}
	testing.expect_value(t, apply_object_data(&database, &data, .Unit), Error.None)

	// The original-table modification overrides the base table.
	health, health_found = find_integer(&database, .Unit, code("hfoo"), code("uhpm"))
	testing.expect(t, health_found)
	testing.expect_value(t, health, 500)

	// The custom entry is a copy of the standard object with its own
	// modifications on top, and it does not disturb the original.
	custom_health, custom_health_found := find_integer(&database, .Unit, code("x000"), code("uhpm"))
	testing.expect(t, custom_health_found)
	testing.expect_value(t, custom_health, 700)
	custom_name, custom_name_found := find_text(&database, .Unit, code("x000"), code("unam"))
	testing.expect(t, custom_name_found)
	testing.expect_value(t, custom_name, "Custom Footman")

	base_name, base_name_found := find_text(&database, .Unit, code("hfoo"), code("unam"))
	testing.expect(t, base_name_found)
	testing.expect_value(t, base_name, "Footman")

	object, object_found := find_object(&database, .Unit, code("x000"))
	testing.expect(t, object_found)
	testing.expect_value(t, object.base_id, code("hfoo"))

	// A custom entry cloning a custom entry: the clone sees the
	// already-applied object, so chains work without a second pass.
	chained_modifications := [?]object_data.Modification {
		{id = code("uhpm"), value_type = .Integer, value = i32(900)},
	}
	chained := [?]object_data.Entry {
		{old_id = code("x000"), new_id = code("x001"), modifications = chained_modifications[:]},
	}
	chained_data := object_data.Object_Data {
		custom = chained[:],
	}
	testing.expect_value(t, apply_object_data(&database, &chained_data, .Unit), Error.None)
	chained_name, chained_name_found := find_text(&database, .Unit, code("x001"), code("unam"))
	testing.expect(t, chained_name_found)
	testing.expect_value(t, chained_name, "Custom Footman")
	chained_health, _ := find_integer(&database, .Unit, code("x001"), code("uhpm"))
	testing.expect_value(t, chained_health, 900)
}

@(test)
target_table_comes_from_the_metadata_not_the_extension :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	unit_table := build_slk({{"unitBalanceID", "HP"}, {"hfoo", "420"}})
	defer delete(unit_table)
	testing.expect_value(t, load_table(&database, .Unit_Balance, unit_table), Error.None)
	item_table := build_slk({{"itemID", "goldcost"}, {"amrc", "100"}})
	defer delete(item_table)
	testing.expect_value(t, load_table(&database, .Item_Data, item_table), Error.None)

	// (4)WarChasers.w3m has no war3map.w3t and keeps item
	// modifications in its war3map.w3u, so a w3u entry whose old id is
	// an item rawcode must land on the item.
	item_modifications := [?]object_data.Modification {
		{id = code("igol"), value_type = .Integer, value = i32(1200)},
	}
	// An entry the base tables do not know falls back to its
	// modifications' metadata rows, which name ItemData.
	unknown_modifications := [?]object_data.Modification {
		{id = code("igol"), value_type = .Integer, value = i32(75)},
	}
	entries := [?]object_data.Entry {
		{old_id = code("amrc"), modifications = item_modifications[:]},
		{old_id = code("zzzz"), modifications = unknown_modifications[:]},
	}
	data := object_data.Object_Data {
		original = entries[:],
	}
	// Applied as a unit file, the way the map stores it.
	testing.expect_value(t, apply_object_data(&database, &data, .Unit), Error.None)

	gold, gold_found := find_integer(&database, .Item, code("amrc"), code("igol"))
	testing.expect(t, gold_found)
	testing.expect_value(t, gold, 1200)
	_, on_unit_table := find_object(&database, .Unit, code("amrc"))
	testing.expect(t, !on_unit_table, "an item entry must not appear among the units")

	unknown_gold, unknown_found := find_integer(&database, .Item, code("zzzz"), code("igol"))
	testing.expect(t, unknown_found)
	testing.expect_value(t, unknown_gold, 75)

	testing.expect_value(t, database.stats.modifications_unresolved, 0)
	testing.expect_value(t, database.stats.data_pointer_mismatches, 0)
}

// A rawcode two families both know can only come from custom entries,
// since the stock families share none. The file being read decides.
@(test)
a_rawcode_in_two_families_stays_with_the_file :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	unit_table := build_slk({{"unitBalanceID", "HP"}, {"A000", "420"}})
	defer delete(unit_table)
	testing.expect_value(t, load_table(&database, .Unit_Balance, unit_table), Error.None)
	ability_table := build_slk({{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4"}, {"A000", "1", "1", "1", "1", "1"}})
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	modifications := [?]object_data.Modification {
		{id = code("acas"), value_type = .Integer, level = 1, value = i32(9)},
	}
	entries := [?]object_data.Entry{{old_id = code("A000"), modifications = modifications[:]}}
	data := object_data.Object_Data {
		original = entries[:],
	}
	testing.expect_value(t, apply_object_data(&database, &data, .Ability), Error.None)

	value, found := find_integer(&database, .Ability, code("A000"), code("acas"), 1)
	testing.expect(t, found)
	testing.expect_value(t, value, 9)
	_, on_the_unit := find_field(&database, .Unit, code("A000"), code("acas"))
	testing.expect(t, !on_the_unit, "the ability file must not modify the unit of the same rawcode")
}

@(test)
lookup_by_name_answers_from_the_object :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)
	load_test_metadata(t, &database)

	ability_table := build_slk(
		{
			{"alias", "hero", "Cast1", "Cast2", "Cast3", "Cast4", "DataE1"},
			{"Afbt", "1", "1", "1", "1", "1", "20"},
		},
	)
	defer delete(ability_table)
	testing.expect_value(t, load_table(&database, .Ability_Data, ability_table), Error.None)

	value, found := find_value_by_name(&database, .Ability, code("Afbt"), "datae", 1)
	testing.expect(t, found)
	number, is_number := value_integer(value)
	testing.expect(t, is_number)
	testing.expect_value(t, number, 20)

	field_id, field_found := find_field_id_by_name(&database, .Ability, code("Afbt"), "Cast")
	testing.expect(t, field_found)
	testing.expect_value(t, field_id, code("acas"))

	_, missing := find_value_by_name(&database, .Ability, code("Afbt"), "NoSuchField")
	testing.expect(t, !missing)
}

@(test)
malformed_inputs_error_cleanly :: proc(t: ^testing.T) {
	database := make_database()
	defer destroy(&database)

	testing.expect_value(t, load_metadata(&database, .Unit, "not an slk"), Error.Invalid_Metadata)
	testing.expect_value(t, load_metadata(&database, .Unit, ""), Error.Invalid_Metadata)

	// A well-formed SLK without an ID column is not metadata.
	headerless := build_slk({{"other"}, {"value"}})
	defer delete(headerless)
	testing.expect_value(t, load_metadata(&database, .Unit, headerless), Error.Invalid_Metadata)

	load_test_metadata(t, &database)
	testing.expect_value(t, load_table(&database, .Unit_Balance, "not an slk"), Error.Invalid_Table)
	// Profile is not a table anyone can load rows from.
	testing.expect_value(t, load_table(&database, .Profile, "not an slk"), Error.Unknown_Table)
	testing.expect_value(t, load_table(&database, .None, "not an slk"), Error.Unknown_Table)

	// An empty file and a header-only table are both empty, not fatal.
	header_only := build_slk({{"unitBalanceID", "HP"}})
	defer delete(header_only)
	testing.expect_value(t, load_table(&database, .Unit_Balance, header_only), Error.Invalid_Table)
	testing.expect_value(t, load_profile(&database, ""), Error.None)
	testing.expect_value(t, len(database.objects[.Unit]), 0)
}

// The metadata's 70 type names collapse into four storage classes,
// and over the whole corpus the class matches the value tag the
// object-data file writes for that field.
@(test)
storage_classes_follow_the_metadata_type :: proc(t: ^testing.T) {
	expected := [?]struct {
		type_name: string,
		storage:   Storage_Class,
	} {
		{"int", .Integer},
		{"bool", .Integer},
		{"teamColor", .Integer},
		{"detectionType", .Integer},
		{"real", .Real},
		{"unreal", .Unreal},
		{"string", .String},
		{"unitList", .String},
		{"icon", .String},
		{"abilCode", .String},
		{"", .String},
	}
	for pair in expected {
		testing.expect_value(t, storage_class_for_type(pair.type_name), pair.storage)
	}
	// Type names are matched case insensitively, like every other name
	// in this layer.
	testing.expect_value(t, storage_class_for_type("Unreal"), Storage_Class.Unreal)
}

@(test)
extension_shapes_and_kinds_are_known :: proc(t: ^testing.T) {
	expected := [?]struct {
		extension: string,
		kind:      Object_Kind,
	} {
		{"w3u", .Unit},
		{"w3t", .Item},
		{"w3a", .Ability},
		{"w3h", .Buff},
		{"w3b", .Destructable},
		{"w3d", .Doodad},
		{"w3q", .Upgrade},
	}
	for pair in expected {
		kind, known := kind_for_extension(pair.extension)
		testing.expect(t, known)
		testing.expect_value(t, kind, pair.kind)
	}
	_, unknown := kind_for_extension("w3e")
	testing.expect(t, !unknown)
}
