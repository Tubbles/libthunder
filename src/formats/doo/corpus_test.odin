package doo

// Corpus tests against the stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (tmp/doo_reader.py and tmp/doo_spotcheck.py,
// WI-0012 log), not with this parser.
//
// The gated sweep (THUNDER_CORPUS_SWEEP=1) parses both placement files
// of every one of the 186 stock maps. Every file must parse to exact
// end of file.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import mpq "thunder:formats/mpq"

@(private)
corpus_open_map :: proc(t: ^testing.T, elements: []string) -> (archive: ^mpq.Archive, opened: bool) {
	full_path, _ := filepath.join(elements)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return nil, false
	}
	opened_archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	return opened_archive, open_error == .None
}

// A Reign of Chaos map: v7/sub9 in both files, with drop tables, the
// corpus's only unit carrying an inventory item, a modified ability,
// and an empty special-doodad section.
@(test)
corpus_war_chasers_placement_decodes :: proc(t: ^testing.T) {
	archive, opened := corpus_open_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "Scenario", "(4)WarChasers.w3m"},
	)
	if !opened {
		return
	}
	defer mpq.close(archive)

	units_data, units_read_error := mpq.read_file(archive, "war3mapUnits.doo")
	defer delete(units_data)
	testing.expect_value(t, units_read_error, mpq.Error.None)
	units, units_error := parse_units(units_data)
	defer destroy(&units)
	testing.expect_value(t, units_error, Error.None)
	testing.expect_value(t, units.version, VERSION_REIGN_OF_CHAOS)
	testing.expect_value(t, units.sub_version, SUB_VERSION_REIGN_OF_CHAOS)
	testing.expect_value(t, len(units.units), 342)
	if len(units.units) != 342 {
		return
	}

	start_location := units.units[0]
	testing.expect_value(t, start_location.type_id, [4]u8{'s', 'l', 'o', 'c'})
	testing.expect_value(t, start_location.position, [3]f32{-7744, -9152, 128})
	testing.expect_value(t, start_location.owning_player, 0)
	testing.expect_value(t, start_location.creation_number, 17)
	random_any, is_any := start_location.random_data.(Random_Any)
	testing.expect(t, is_any, "start location should carry a mode 0 random block")
	testing.expect_value(t, random_any.level, 1)
	testing.expect_value(t, random_any.item_class, 0)

	// The only placed unit in the whole corpus with an inventory item.
	carrier := units.units[217]
	testing.expect_value(t, carrier.type_id, [4]u8{'H', 'C', '2', '0'})
	testing.expect_value(t, carrier.owning_player, 11)
	testing.expect_value(t, carrier.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, len(carrier.inventory), 1)
	testing.expect_value(t, carrier.inventory[0].slot, 0)
	testing.expect_value(t, carrier.inventory[0].id, [4]u8{'a', 'n', 'k', 'h'})
	testing.expect_value(t, len(carrier.dropped_item_sets), 2)
	testing.expect_value(t, len(carrier.dropped_item_sets[0].items), 1)
	testing.expect_value(t, carrier.dropped_item_sets[0].items[0].id, [4]u8{'Y', 'Y', 'I', '6'})
	testing.expect_value(t, carrier.dropped_item_sets[0].items[0].chance, 100)

	caster := units.units[299]
	testing.expect_value(t, caster.type_id, [4]u8{'n', 's', 't', 'h'})
	testing.expect_value(t, len(caster.modified_abilities), 1)
	testing.expect_value(t, caster.modified_abilities[0].id, [4]u8{'A', 'C', 'b', 'l'})
	testing.expect_value(t, caster.modified_abilities[0].autocast_active, 1)
	testing.expect_value(t, caster.modified_abilities[0].level, 0)

	doodads_data, doodads_read_error := mpq.read_file(archive, "war3map.doo")
	defer delete(doodads_data)
	testing.expect_value(t, doodads_read_error, mpq.Error.None)
	doodads, doodads_error := parse_doodads(doodads_data)
	defer destroy(&doodads)
	testing.expect_value(t, doodads_error, Error.None)
	testing.expect_value(t, doodads.version, VERSION_REIGN_OF_CHAOS)
	testing.expect_value(t, doodads.sub_version, SUB_VERSION_REIGN_OF_CHAOS)
	testing.expect_value(t, len(doodads.doodads), 831)
	// The section is present in v7 files too, just empty.
	testing.expect_value(t, doodads.special_doodad_version, SPECIAL_DOODAD_VERSION)
	testing.expect_value(t, len(doodads.special_doodads), 0)
	if len(doodads.doodads) != 831 {
		return
	}

	tree := doodads.doodads[0]
	testing.expect_value(t, tree.type_id, [4]u8{'Y', 'O', 's', 't'})
	testing.expect_value(t, tree.variation, 0)
	testing.expect_value(t, tree.position, [3]f32{-8448, -7872, 128})
	testing.expect_value(t, tree.flags, 2)
	testing.expect_value(t, tree.life_percentage, 255)
	testing.expect_value(t, tree.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, len(tree.dropped_item_sets), 0)
	testing.expect_value(t, tree.creation_number, 0)

	destructable := doodads.doodads[13]
	testing.expect_value(t, destructable.type_id, [4]u8{'Y', 'T', 'l', 'b'})
	testing.expect_value(t, destructable.position, [3]f32{-5408, 2720, 48})
	testing.expect_value(t, destructable.life_percentage, 100)
	testing.expect_value(t, destructable.creation_number, 813)

	last := doodads.doodads[830]
	testing.expect_value(t, last.type_id, [4]u8{'L', 'O', 's', 'm'})
	testing.expect_value(t, last.variation, 1)
	testing.expect_value(t, last.creation_number, 830)
}

// A Frozen Throne map: v8/sub11 in both files and the corpus's largest
// special-doodad section.
@(test)
corpus_ruins_of_stratholme_placement_decodes :: proc(t: ^testing.T) {
	archive, opened := corpus_open_map(
		t,
		{
			#directory,
			"..",
			"..",
			"..",
			"data",
			"Warcraft III",
			"Maps",
			"FrozenThrone",
			"(6)RuinsOfStratholme.w3x",
		},
	)
	if !opened {
		return
	}
	defer mpq.close(archive)

	units_data, units_read_error := mpq.read_file(archive, "war3mapUnits.doo")
	defer delete(units_data)
	testing.expect_value(t, units_read_error, mpq.Error.None)
	units, units_error := parse_units(units_data)
	defer destroy(&units)
	testing.expect_value(t, units_error, Error.None)
	testing.expect_value(t, units.version, VERSION_FROZEN_THRONE)
	testing.expect_value(t, units.sub_version, SUB_VERSION_FROZEN_THRONE)
	testing.expect_value(t, len(units.units), 170)
	if len(units.units) != 170 {
		return
	}

	start_location := units.units[1]
	testing.expect_value(t, start_location.type_id, [4]u8{'s', 'l', 'o', 'c'})
	testing.expect_value(t, start_location.variation, 1)
	testing.expect_value(t, start_location.position, [3]f32{2944, -64, -13.875})
	testing.expect_value(t, start_location.owning_player, 1)
	testing.expect_value(t, start_location.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, start_location.creation_number, 0)

	creep := units.units[85]
	testing.expect_value(t, creep.type_id, [4]u8{'n', 's', 'k', 'g'})
	testing.expect_value(t, creep.owning_player, 12)
	testing.expect_value(t, creep.hit_points, -1)
	testing.expect_value(t, creep.gold_amount, 12500)
	testing.expect_value(t, creep.target_acquisition, -2)
	testing.expect_value(t, creep.hero_level, 1)
	testing.expect_value(t, creep.hero_strength, 0)
	testing.expect_value(t, len(creep.dropped_item_sets), 1)
	testing.expect_value(t, creep.dropped_item_sets[0].items[0].id, [4]u8{'Y', 'k', 'I', '1'})
	testing.expect_value(t, creep.dropped_item_sets[0].items[0].chance, 100)
	testing.expect_value(t, creep.creation_number, 85)

	doodads_data, doodads_read_error := mpq.read_file(archive, "war3map.doo")
	defer delete(doodads_data)
	testing.expect_value(t, doodads_read_error, mpq.Error.None)
	doodads, doodads_error := parse_doodads(doodads_data)
	defer destroy(&doodads)
	testing.expect_value(t, doodads_error, Error.None)
	testing.expect_value(t, doodads.version, VERSION_FROZEN_THRONE)
	testing.expect_value(t, doodads.sub_version, SUB_VERSION_FROZEN_THRONE)
	testing.expect_value(t, len(doodads.doodads), 5242)
	testing.expect_value(t, doodads.special_doodad_version, SPECIAL_DOODAD_VERSION)
	testing.expect_value(t, len(doodads.special_doodads), 36)
	if len(doodads.doodads) != 5242 || len(doodads.special_doodads) != 36 {
		return
	}

	first := doodads.doodads[0]
	testing.expect_value(t, first.type_id, [4]u8{'J', 'T', 'c', 't'})
	testing.expect_value(t, first.position, [3]f32{1088, -2240, -0.1875})
	testing.expect_value(t, first.flags, 2)
	testing.expect_value(t, first.life_percentage, 100)
	// No doodad in any stock map carries drop data.
	testing.expect_value(t, first.item_table_id, NO_ITEM_TABLE)
	testing.expect_value(t, len(first.dropped_item_sets), 0)
	testing.expect_value(t, first.creation_number, 0)

	cliff_doodad := doodads.special_doodads[0]
	testing.expect_value(t, cliff_doodad.type_id, [4]u8{'Y', 'C', 'x', '1'})
	testing.expect_value(t, cliff_doodad.variation, 0)
	testing.expect_value(t, cliff_doodad.grid_x, 42)
	testing.expect_value(t, cliff_doodad.grid_y, 36)
	testing.expect_value(t, doodads.special_doodads[1].type_id, [4]u8{'Y', 'C', 'x', '4'})
	testing.expect_value(t, doodads.special_doodads[1].grid_x, 38)
	testing.expect_value(t, doodads.special_doodads[1].grid_y, 39)
}

@(private)
Sweep_Totals :: struct {
	files:                  int,
	failed:                 int,
	reign_of_chaos_files:   int,
	frozen_throne_files:    int,
	placed_units:           int,
	placed_doodads:         int,
	placed_special_doodads: int,
}

@(private)
sweep_archive :: proc(archive: ^mpq.Archive, map_path: string, totals: ^Sweep_Totals) {
	units_data, units_read_error := mpq.read_file(archive, "war3mapUnits.doo")
	defer delete(units_data)
	if units_read_error != .None {
		log.infof("war3mapUnits.doo unreadable (%v): %s", units_read_error, map_path)
		totals.failed += 1
	} else {
		units, error := parse_units(units_data)
		defer destroy(&units)
		if error != .None {
			log.infof("units parse failure (%v): %s", error, map_path)
			totals.failed += 1
		} else {
			totals.files += 1
			totals.placed_units += len(units.units)
			sweep_count_version(units.version, totals)
		}
	}

	doodads_data, doodads_read_error := mpq.read_file(archive, "war3map.doo")
	defer delete(doodads_data)
	if doodads_read_error != .None {
		log.infof("war3map.doo unreadable (%v): %s", doodads_read_error, map_path)
		totals.failed += 1
		return
	}
	doodads, error := parse_doodads(doodads_data)
	defer destroy(&doodads)
	if error != .None {
		log.infof("doodads parse failure (%v): %s", error, map_path)
		totals.failed += 1
		return
	}
	totals.files += 1
	totals.placed_doodads += len(doodads.doodads)
	totals.placed_special_doodads += len(doodads.special_doodads)
	sweep_count_version(doodads.version, totals)
}

@(private)
sweep_count_version :: proc(version: i32, totals: ^Sweep_Totals) {
	switch version {
	case VERSION_REIGN_OF_CHAOS:
		totals.reign_of_chaos_files += 1
	case VERSION_FROZEN_THRONE:
		totals.frozen_throne_files += 1
	}
}

// Parses both placement files of every stock map. Gated because it
// opens every archive in the corpus.
@(test)
corpus_sweep_all_placement :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	data_root, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III"})
	defer delete(data_root)
	if !os.exists(data_root) {
		log.info("corpus absent, skipping")
		return
	}

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
			pattern := fmt.aprintf("%s/Maps/%s/*.%s", data_root, subdirectory, map_extension)
			defer delete(pattern)
			matches, _ := filepath.glob(pattern)
			append(&map_paths, ..matches)
			delete(matches)
		}
	}
	slice.sort(map_paths[:])

	totals: Sweep_Totals
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
		sweep_archive(archive, map_path, &totals)
	}

	log.infof(
		"sweep: %d maps opened, %d placement files (%d v7, %d v8), %d failed",
		maps_opened,
		totals.files,
		totals.reign_of_chaos_files,
		totals.frozen_throne_files,
		totals.failed,
	)
	log.infof(
		"placed: %d units, %d doodads, %d special doodads",
		totals.placed_units,
		totals.placed_doodads,
		totals.placed_special_doodads,
	)
	testing.expect_value(t, totals.failed, 0)
	testing.expect_value(t, maps_opened, 186)
	testing.expect_value(t, totals.files, 372)
	testing.expect_value(t, totals.reign_of_chaos_files, 90)
	testing.expect_value(t, totals.frozen_throne_files, 282)
}
