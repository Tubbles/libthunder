package gamedata

// Corpus tests against the retail 1.29.2 archives and the stock maps
// in the git-ignored data/ directory; skipped cleanly when the corpus
// is absent. Every expected value was derived with an independent
// python3 probe over the staged raw members (tmp/wi0015_probe.py,
// tmp/wi0015_probe2.py, WI-0015 log), which parses SYLK, the profile
// TXT grammar and the object-data container from their format
// descriptions rather than through this package.
//
// The gated sweep (THUNDER_CORPUS_SWEEP=1) assembles the whole base
// database and then applies every object-data file in the corpus: all
// seven war3map.* members across the 186 stock maps, the
// war3campaign.* members of DemoCampaign.w3n, and the war3map.*
// members of the campaign's three embedded maps.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"
import mpq "thunder:formats/mpq"
import object_data "thunder:formats/object_data"

@(private = "file")
Corpus :: struct {
	archives: [dynamic]^mpq.Archive,
	database: Database,
}

@(private = "file")
corpus_root :: proc() -> string {
	root, _ := filepath.join({#directory, "..", "..", "data", "Warcraft III"})
	return root
}

// Opens the four base archives in priority order and assembles the
// base database. Returns false when the corpus is absent.
@(private = "file")
open_corpus :: proc(t: ^testing.T, corpus: ^Corpus) -> bool {
	root := corpus_root()
	defer delete(root)
	if !os.exists(root) {
		log.info("corpus absent, skipping")
		return false
	}

	corpus.archives = make([dynamic]^mpq.Archive)
	names := BASE_ARCHIVES
	for name in names {
		path, _ := filepath.join({root, name})
		defer delete(path)
		archive, error := mpq.open(path)
		if error != .None {
			log.infof("archive open failed (%v): %s", error, path)
			return false
		}
		append(&corpus.archives, archive)
	}

	corpus.database = make_database()
	error := load_base(&corpus.database, Archive_Set{archives = corpus.archives[:]})
	testing.expect_value(t, error, Error.None)
	return error == .None
}

@(private = "file")
close_corpus :: proc(corpus: ^Corpus) {
	destroy(&corpus.database)
	for archive in corpus.archives {
		mpq.close(archive)
	}
	delete(corpus.archives)
}

// The assembled Footman, plus the two abilities that pin the data
// letter mapping and the per-level tooltip split.
@(test)
corpus_assembled_entries_carry_the_stock_values :: proc(t: ^testing.T) {
	corpus: Corpus
	if !open_corpus(t, &corpus) {
		return
	}
	defer close_corpus(&corpus)
	database := &corpus.database

	testing.expect_value(t, database.stats.metadata_files, 9)
	testing.expect_value(t, database.stats.metadata_rows, 2300)

	// One object per distinct key in each family's tables. UnitWeapons
	// carries one row (nrmf) its sibling unit tables lack, so the unit
	// family has 837 members against the other tables' 836; the blank
	// keys in AbilityData (4) and AbilityBuffData (243) are skipped.
	expected_counts := [Object_Kind]int {
		.Unit         = 837,
		.Item         = 273,
		.Ability      = 799,
		.Buff         = 237,
		.Destructable = 247,
		.Upgrade      = 89,
		.Doodad       = 469,
	}
	for kind in Object_Kind {
		testing.expect_value(t, len(database.objects[kind]), expected_counts[kind])
	}

	footman, _ := rawcode("hfoo")
	health, health_found := find_integer(database, .Unit, footman, must_code("uhpm"))
	testing.expect(t, health_found)
	testing.expect_value(t, health, 420)
	gold, _ := find_integer(database, .Unit, footman, must_code("ugol"))
	testing.expect_value(t, gold, 135)
	lumber, lumber_found := find_integer(database, .Unit, footman, must_code("ulum"))
	testing.expect(t, lumber_found)
	testing.expect_value(t, lumber, 0)
	defense, _ := find_integer(database, .Unit, footman, must_code("udef"))
	testing.expect_value(t, defense, 2)
	damage_bonus, _ := find_integer(database, .Unit, footman, must_code("ua1b"))
	testing.expect_value(t, damage_bonus, 11)
	cooldown, cooldown_found := find_real(database, .Unit, footman, must_code("ua1c"))
	testing.expect(t, cooldown_found)
	testing.expect_value(t, cooldown, 1.35)
	model, model_found := find_text(database, .Unit, footman, must_code("umdl"))
	testing.expect(t, model_found)
	testing.expect_value(t, model, "units\\human\\Footman\\Footman")
	race, _ := find_text(database, .Unit, footman, must_code("urac"))
	testing.expect_value(t, race, "human")
	abilities, _ := find_text(database, .Unit, footman, must_code("uabi"))
	testing.expect_value(t, abilities, "Adef,Aihn")

	// Profile fields: a name from the Strings family, a packed value
	// from the Func family split into its two element fields.
	name, name_found := find_text(database, .Unit, footman, must_code("unam"))
	testing.expect(t, name_found)
	testing.expect_value(t, name, "Footman")
	button_x, button_x_found := find_integer(database, .Unit, footman, must_code("ubpx"))
	testing.expect(t, button_x_found)
	testing.expect_value(t, button_x, 0)
	button_y, button_y_found := find_integer(database, .Unit, footman, must_code("ubpy"))
	testing.expect(t, button_y_found)
	testing.expect_value(t, button_y, 0)

	// data=5 is DataE. Afbt's DataE1 is 20, the number its stock
	// tooltip quotes as the bonus damage against summoned units.
	spell_damage, spell_damage_found := find_integer(database, .Ability, must_code("Afbt"), must_code("fbk5"), 1)
	testing.expect(t, spell_damage_found)
	testing.expect_value(t, spell_damage, 20)

	// Blizzard: DataA/DataB/DataF at level 1, with DataG through DataI
	// unset in the table.
	blizzard := must_code("AHbz")
	waves, waves_found := find_integer(database, .Ability, blizzard, must_code("Hbz1"), 1)
	testing.expect(t, waves_found)
	testing.expect_value(t, waves, 6)
	wave_damage, _ := find_real(database, .Ability, blizzard, must_code("Hbz2"), 1)
	testing.expect_value(t, wave_damage, 30)
	area, _ := find_real(database, .Ability, blizzard, must_code("Hbz6"), 1)
	testing.expect_value(t, area, 150)

	// One quoted CSV key carries one tooltip per level, and the quotes
	// are what keep the commas inside each level's text.
	for level in 1 ..= 3 {
		tooltip, tooltip_found := find_text(database, .Ability, blizzard, must_code("aub1"), level)
		testing.expect(t, tooltip_found)
		testing.expect(t, strings.has_prefix(tooltip, "Calls down <AHbz,DataA"))
		testing.expect(t, strings.contains(tooltip, "damage to units in an area."))
	}
	_, past_the_last_level := find_value(database, .Ability, blizzard, must_code("aub1"), 4)
	testing.expect(t, !past_the_last_level, "a level the file never wrote must miss")

	// A leading space that ini's default trimming would have eaten.
	suffix, suffix_found := find_text(database, .Ability, must_code("Afbk"), must_code("ansf"))
	testing.expect(t, suffix_found)
	testing.expect_value(t, suffix, " (Spell Breaker)")

	log.infof(
		"base database: %d metadata rows, %d table values, %d profile values, %d profile sections skipped, %d profile keys unresolved",
		database.stats.metadata_rows,
		database.stats.table_values,
		database.stats.profile_values,
		database.stats.profile_sections_skipped,
		database.stats.profile_keys_unresolved,
	)
}

// The one gameplay-data member in the corpus whose content depends on
// the archive order: Units\NightElfAbilityStrings.txt exists in
// War3Local, War3x and War3xLocal, and only War3xLocal's copy drops
// the closing clause from ability AEtq's research tooltip.
@(test)
corpus_archive_priority_decides_the_night_elf_tooltip :: proc(t: ^testing.T) {
	corpus: Corpus
	if !open_corpus(t, &corpus) {
		return
	}
	defer close_corpus(&corpus)

	tooltip, found := find_text(&corpus.database, .Ability, must_code("AEtq"), must_code("arut"))
	testing.expect(t, found, "AEtq Researchubertip missing")
	testing.expect(t, strings.has_prefix(tooltip, "Causes rains of healing energy"))
	testing.expect(
		t,
		strings.has_suffix(tooltip, "|nLasts <AEtq,Dur1> seconds."),
		"War3xLocal's copy must win over War3x's longer line",
	)
	testing.expect(
		t,
		!strings.contains(tooltip, "initial duration of invulnerability"),
		"the War3x wording means the archive priority was not applied",
	)
}

// (4)WarChasers.w3m is a RoC-era map with no war3map.w3t at all: its
// war3map.w3u mixes unit and item entries, and 35 item gold-cost
// modifications ride in it. The metadata row for `igol` names
// ItemData, so those entries have to land among the items.
@(test)
corpus_war_chasers_item_costs_land_on_items :: proc(t: ^testing.T) {
	corpus: Corpus
	if !open_corpus(t, &corpus) {
		return
	}
	defer close_corpus(&corpus)
	database := &corpus.database

	root := corpus_root()
	defer delete(root)
	map_path, _ := filepath.join({root, "Maps", "Scenario", "(4)WarChasers.w3m"})
	defer delete(map_path)
	archive, open_error := mpq.open(map_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	if open_error != .None {
		return
	}
	defer mpq.close(archive)

	// The map has no war3map.w3t, so exactly one object-data member is
	// found.
	files, error := load_map_object_data(database, archive)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, files, 1)
	testing.expect_value(t, database.stats.modifications_unresolved, 0)
	testing.expect_value(t, database.stats.data_pointer_mismatches, 0)

	gold_cost := must_code("igol")
	expected := [?]struct {
		item: string,
		cost: i64,
	}{{"amrc", 1200}, {"ankh", 3000}, {"modt", 2000}, {"ccmd", 1100}, {"ofir", 800}, {"ofro", 1000}}
	for entry in expected {
		item := must_code(entry.item)
		value, found := find_integer(database, .Item, item, gold_cost)
		testing.expect(t, found, entry.item)
		testing.expect_value(t, value, entry.cost)
		_, on_the_unit_table := find_object(database, .Unit, item)
		testing.expect(t, !on_the_unit_table, "an item entry must not appear among the units")
	}

	// The map's 25 custom entries split by the same rule: 24 clone
	// units and one clones an item, so each family grows by exactly
	// what belongs to it.
	testing.expect_value(t, len(database.objects[.Item]), 274)
	testing.expect_value(t, len(database.objects[.Unit]), 861)

	// The full layering on one real item. Ankh of Reincarnation costs
	// 450 in ItemData.slk, the map's original-table entry raises it to
	// 3000, and its custom entry IC17 clones the ankh and asks 5000.
	ankh := must_code("ankh")
	ankh_cost, ankh_found := find_integer(database, .Item, ankh, gold_cost)
	testing.expect(t, ankh_found)
	testing.expect_value(t, ankh_cost, 3000)

	custom_item, custom_found := find_object(database, .Item, must_code("IC17"))
	testing.expect(t, custom_found, "the custom item is missing")
	testing.expect_value(t, custom_item.base_id, ankh)
	custom_cost, custom_cost_found := find_integer(database, .Item, must_code("IC17"), gold_cost)
	testing.expect(t, custom_cost_found)
	testing.expect_value(t, custom_cost, 5000)
	// Inherited from the clone rather than restated by the map.
	inherited, inherited_found := find_text(database, .Item, must_code("IC17"), must_code("iabi"))
	testing.expect(t, inherited_found)
	testing.expect_value(t, inherited, "AIrc")

	log.infof("WarChasers: %d modifications applied", database.stats.modifications_applied)
}

@(private = "file")
must_code :: proc(text: string) -> [4]u8 {
	id, _ := rawcode(text)
	return id
}

@(private = "file")
Sweep_Totals :: struct {
	files:            int,
	failed:           int,
	entries:          int,
	modification_ids: map[[4]u8]bool,
}

@(private = "file")
sweep_archive :: proc(
	database: ^Database,
	archive: ^mpq.Archive,
	label: string,
	totals: ^Sweep_Totals,
) {
	prefix := "war3map"
	if strings.has_suffix(label, ".w3n") {
		prefix = "war3campaign"
	}
	extensions := [?]string{"w3u", "w3t", "w3b", "w3d", "w3a", "w3h", "w3q"}
	for extension in extensions {
		member := fmt.aprintf("%s.%s", prefix, extension)
		defer delete(member)
		data, read_error := mpq.read_file(archive, member)
		defer delete(data)
		if read_error != .None {
			continue
		}
		shape, shape_known := object_data.shape_for_extension(extension)
		kind, kind_known := kind_for_extension(extension)
		if !shape_known || !kind_known {
			totals.failed += 1
			continue
		}
		parsed, parse_error := object_data.parse(data, shape)
		defer object_data.destroy(&parsed)
		if parse_error != .None {
			log.infof("parse failure (%v): %s %s", parse_error, label, member)
			totals.failed += 1
			continue
		}
		for entry in parsed.original {
			totals.entries += 1
			for modification in entry.modifications {
				totals.modification_ids[modification.id] = true
			}
		}
		for entry in parsed.custom {
			totals.entries += 1
			for modification in entry.modifications {
				totals.modification_ids[modification.id] = true
			}
		}
		if apply_object_data(database, &parsed, kind) != .None {
			totals.failed += 1
			continue
		}
		totals.files += 1
	}
}

@(private = "file")
sweep_embedded_maps :: proc(database: ^Database, campaign: ^mpq.Archive, tmp_root: string, totals: ^Sweep_Totals) {
	listfile, listfile_error := mpq.read_file(campaign, "(listfile)")
	defer delete(listfile)
	if listfile_error != .None {
		totals.failed += 1
		return
	}
	text := string(listfile)
	for line in strings.split_lines_iterator(&text) {
		member := strings.trim_space(line)
		if !strings.has_suffix(member, ".w3x") && !strings.has_suffix(member, ".w3m") {
			continue
		}
		embedded, embedded_error := mpq.read_file(campaign, member)
		defer delete(embedded)
		if embedded_error != .None {
			totals.failed += 1
			continue
		}
		staged := fmt.aprintf("%s/gamedata_sweep_%s", tmp_root, member)
		defer delete(staged)
		if write_error := os.write_entire_file(staged, embedded); write_error != nil {
			totals.failed += 1
			continue
		}
		archive, open_error := mpq.open(staged)
		if open_error != .None {
			totals.failed += 1
			continue
		}
		defer mpq.close(archive)
		sweep_archive(database, archive, member, totals)
	}
}

// Assembles the base database and applies every corpus map's object
// data to it. The maps share one database: the sweep asks whether
// every file loads and every modification id resolves, not what any
// single map's values are, and a fresh base per map would re-read the
// whole gameplay data 187 times.
@(test)
corpus_sweep_assembles_every_map :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	corpus: Corpus
	if !open_corpus(t, &corpus) {
		return
	}
	defer close_corpus(&corpus)
	database := &corpus.database

	// Fixed corpus, so the metadata numbers are asserted exactly: a
	// drop here means a metadata file stopped loading.
	testing.expect_value(t, database.stats.metadata_files, 9)
	testing.expect_value(t, database.stats.metadata_rows, 2300)
	testing.expect_value(t, database.stats.metadata_duplicate_ids, 0)
	testing.expect_value(t, database.stats.metadata_unknown_tables, 0)

	root := corpus_root()
	defer delete(root)
	tmp_root, _ := filepath.join({#directory, "..", "..", "tmp"})
	defer delete(tmp_root)

	subdirectories := [?]string{"", "Scenario", "FrozenThrone", "FrozenThrone/Scenario", "FrozenThrone/Community"}
	map_extensions := [?]string{"w3m", "w3x"}
	map_paths := make([dynamic]string)
	defer {
		for map_path in map_paths {
			delete(map_path)
		}
		delete(map_paths)
	}
	for subdirectory in subdirectories {
		for map_extension in map_extensions {
			pattern := fmt.aprintf("%s/Maps/%s/*.%s", root, subdirectory, map_extension)
			defer delete(pattern)
			matches, _ := filepath.glob(pattern)
			append(&map_paths, ..matches)
			delete(matches)
		}
	}
	slice.sort(map_paths[:])

	totals: Sweep_Totals
	totals.modification_ids = make(map[[4]u8]bool)
	defer delete(totals.modification_ids)
	maps_opened := 0
	for map_path in map_paths {
		archive, open_error := mpq.open(map_path)
		if open_error != .None {
			log.infof("open failed (%v): %s", open_error, map_path)
			totals.failed += 1
			continue
		}
		defer mpq.close(archive)
		maps_opened += 1
		sweep_archive(database, archive, map_path, &totals)
	}

	campaign_path, _ := filepath.join({root, "Campaigns", "DemoCampaign.w3n"})
	defer delete(campaign_path)
	campaign, campaign_error := mpq.open(campaign_path)
	if campaign_error != .None {
		totals.failed += 1
	} else {
		defer mpq.close(campaign)
		sweep_archive(database, campaign, campaign_path, &totals)
		sweep_embedded_maps(database, campaign, tmp_root, &totals)
	}

	unresolved := 0
	for id in totals.modification_ids {
		if _, found := find_descriptor(&database.metadata, id); !found {
			unresolved += 1
		}
	}
	log.infof(
		"sweep: %d maps, %d object-data files, %d entries, %d distinct modification ids, %d applied, %d failed",
		maps_opened,
		totals.files,
		totals.entries,
		len(totals.modification_ids),
		database.stats.modifications_applied,
		totals.failed,
	)
	for kind in Object_Kind {
		log.infof("%v: %d objects", kind, len(database.objects[kind]))
	}

	testing.expect_value(t, totals.failed, 0)
	// The corpus contents are fixed (WI-0011 counted the same 61 files
	// and the WI-0015 survey the same 645 ids), so exact numbers catch
	// enumeration regressions rather than corpus changes.
	testing.expect_value(t, totals.files, 61)
	testing.expect_value(t, len(totals.modification_ids), 645)
	testing.expect_value(t, unresolved, 0)
	testing.expect_value(t, database.stats.modifications_unresolved, 0)
	testing.expect_value(t, database.stats.modification_level_drops, 0)
	testing.expect_value(t, database.stats.data_pointer_mismatches, 0)
}
