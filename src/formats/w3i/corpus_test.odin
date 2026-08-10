package w3i

// Corpus tests against the stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (WI-0010 log, 2026-08-10), not with this
// parser.
//
// This file also hosts the cross-format sweep (gated behind
// THUNDER_CORPUS_SWEEP=1): all five WI-0010 subformats parse from
// every stock map, the wpm/shd dimension invariants hold against the
// same map's w3e, and every TRIGSTR_ reference in w3i resolves
// against the same map's wts. It lives in this package because w3i is
// the one format whose data references the other four.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import mpq "thunder:formats/mpq"
import shd "thunder:formats/shd"
import w3e "thunder:formats/w3e"
import wpm "thunder:formats/wpm"
import wts "thunder:formats/wts"

@(test)
corpus_booty_bay_decodes :: proc(t: ^testing.T) {
	full_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)BootyBay.w3m"})
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3i")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	info, error := parse(data)
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.version, u32(VERSION_REIGN_OF_CHAOS))
	testing.expect_value(t, info.map_version, 29)
	testing.expect_value(t, info.editor_version, 6030)
	testing.expect_value(t, info.name, "TRIGSTR_003")
	testing.expect_value(t, info.author, "TRIGSTR_006")
	testing.expect_value(t, info.recommended_players, "TRIGSTR_004")
	testing.expect_value(t, info.camera_bounds[0], -9728)
	testing.expect_value(t, info.camera_bounds[3], 3584)
	testing.expect_value(t, info.camera_bounds_complements, [4]i32{18, 14, 8, 16})
	testing.expect_value(t, info.playable_width, 160)
	testing.expect_value(t, info.playable_height, 72)
	testing.expect_value(t, info.flags, 39956)
	testing.expect_value(t, info.tileset, 'L')
	testing.expect_value(t, info.campaign_background_number, -1)
	testing.expect_value(t, info.loading_screen_number, -1)
	testing.expect_value(t, info.tail_skipped, false)

	testing.expect_value(t, len(info.players), 2)
	testing.expect_value(t, info.players[0].id, 0)
	testing.expect_value(t, info.players[0].controller, 1)
	testing.expect_value(t, info.players[0].race, 1)
	testing.expect_value(t, info.players[0].name, "TRIGSTR_000")
	testing.expect_value(t, info.players[0].start_x, -8384)
	testing.expect_value(t, info.players[0].start_y, 1792)
	testing.expect_value(t, info.players[0].ally_high_priorities, 2)
	testing.expect_value(t, info.players[1].race, 2)
	testing.expect_value(t, info.players[1].start_x, 8448)
	testing.expect_value(t, len(info.forces), 1)
	testing.expect_value(t, info.forces[0].players, 0xFFFF_FFFF)
	testing.expect_value(t, info.forces[0].name, "TRIGSTR_002")
	testing.expect_value(t, len(info.upgrades), 0)
	testing.expect_value(t, len(info.techs), 0)

	// The map's own wts table resolves the name reference.
	strings_data, strings_read_error := mpq.read_file(archive, "war3map.wts")
	defer delete(strings_data)
	testing.expect_value(t, strings_read_error, mpq.Error.None)
	table, table_error := wts.parse(string(strings_data))
	defer wts.destroy(&table)
	testing.expect_value(t, table_error, wts.Error.None)
	testing.expect_value(t, wts.resolve(&table, info.name), "Booty Bay")
	testing.expect_value(t, wts.resolve(&table, info.author), "Blizzard Entertainment")
	testing.expect_value(t, wts.resolve(&table, info.players[0].name), "Player 1")
}

@(test)
corpus_echo_isles_decodes :: proc(t: ^testing.T) {
	full_path, _ := filepath.join(
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(2)EchoIsles.w3x"},
	)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3i")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	info, error := parse(data)
	defer destroy(&info)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, info.version, u32(VERSION_FROZEN_THRONE))
	testing.expect_value(t, info.map_version, 31)
	testing.expect_value(t, info.editor_version, 6051)
	testing.expect_value(t, info.name, "TRIGSTR_004")
	testing.expect_value(t, info.camera_bounds[0], -6912)
	testing.expect_value(t, info.camera_bounds_complements, [4]i32{6, 6, 4, 8})
	testing.expect_value(t, info.playable_width, 116)
	testing.expect_value(t, info.playable_height, 84)
	testing.expect_value(t, info.flags, 56340)
	testing.expect_value(t, info.tileset, 'L')
	testing.expect_value(t, info.loading_screen_background_number, -1)
	testing.expect_value(t, info.loading_screen_path, "")
	testing.expect_value(t, info.game_data_set, 0)
	testing.expect_value(t, info.fog_style, 0)
	testing.expect_value(t, info.fog_start_z, 3000)
	testing.expect_value(t, info.fog_end_z, 5000)
	testing.expect_value(t, info.fog_density, 0.5)
	testing.expect_value(t, info.fog_color, [4]u8{0, 0, 0, 255})
	testing.expect_value(t, info.global_weather_id, [4]u8{'R', 'A', 'l', 'r'})
	testing.expect_value(t, info.sound_environment, "")
	testing.expect_value(t, info.light_environment, 0)
	testing.expect_value(t, info.water_tint, [4]u8{255, 255, 255, 255})

	testing.expect_value(t, len(info.players), 2)
	testing.expect_value(t, info.players[0].name, "TRIGSTR_001")
	testing.expect_value(t, info.players[0].start_x, -5184)
	testing.expect_value(t, info.players[0].start_y, 2944)
	testing.expect_value(t, info.players[1].race, 2)
	testing.expect_value(t, len(info.forces), 1)

	strings_data, strings_read_error := mpq.read_file(archive, "war3map.wts")
	defer delete(strings_data)
	testing.expect_value(t, strings_read_error, mpq.Error.None)
	table, table_error := wts.parse(string(strings_data))
	defer wts.destroy(&table)
	testing.expect_value(t, table_error, wts.Error.None)
	testing.expect_value(t, wts.resolve(&table, info.name), "Echo Isles")
	testing.expect_value(t, wts.resolve(&table, info.players[0].name), "Player 1")
}

// Checks every TRIGSTR_ reference among the info's strings against
// the map's trigger-string table. Returns the number of references
// seen and how many failed to resolve.
@(private)
test_check_references :: proc(info: ^Map_Info, table: ^wts.Trigger_Strings) -> (references: int, unresolved: int) {
	texts := make([dynamic]string)
	defer delete(texts)
	append(
		&texts,
		info.name,
		info.author,
		info.description,
		info.recommended_players,
		info.loading_screen_text,
		info.loading_screen_title,
		info.loading_screen_subtitle,
		info.prologue_screen_text,
		info.prologue_screen_title,
		info.prologue_screen_subtitle,
	)
	for player in info.players {
		append(&texts, player.name)
	}
	for force in info.forces {
		append(&texts, force.name)
	}
	for random_table in info.random_unit_tables {
		append(&texts, random_table.name)
	}
	for random_table in info.random_item_tables {
		append(&texts, random_table.name)
	}
	for text in texts {
		key, is_reference := wts.reference_key(text)
		if !is_reference {
			continue
		}
		references += 1
		if _, found := wts.lookup(table, key); !found {
			unresolved += 1
		}
	}
	return references, unresolved
}

@(private)
Sweep_Totals :: struct {
	maps:                 int,
	failed:               int,
	version_18:           int,
	version_25:           int,
	trigger_references:   int,
	unresolved_reference: int,
}

@(private)
test_sweep_map :: proc(t: ^testing.T, map_path: string, totals: ^Sweep_Totals) {
	archive, open_error := mpq.open(map_path)
	if open_error != .None {
		log.infof("%v: %s", open_error, map_path)
		totals.failed += 1
		return
	}
	defer mpq.close(archive)

	environment_data, environment_read_error := mpq.read_file(archive, "war3map.w3e")
	defer delete(environment_data)
	pathing_data, pathing_read_error := mpq.read_file(archive, "war3map.wpm")
	defer delete(pathing_data)
	shadow_data, shadow_read_error := mpq.read_file(archive, "war3map.shd")
	defer delete(shadow_data)
	info_data, info_read_error := mpq.read_file(archive, "war3map.w3i")
	defer delete(info_data)
	strings_data, strings_read_error := mpq.read_file(archive, "war3map.wts")
	defer delete(strings_data)
	if environment_read_error != .None ||
	   pathing_read_error != .None ||
	   shadow_read_error != .None ||
	   info_read_error != .None ||
	   strings_read_error != .None {
		log.infof("member missing: %s", map_path)
		totals.failed += 1
		return
	}

	environment, environment_error := w3e.parse(environment_data)
	defer w3e.destroy(&environment)
	pathing_map, pathing_error := wpm.parse(pathing_data)
	defer wpm.destroy(&pathing_map)
	shadow_map, shadow_error := shd.parse(shadow_data, environment.width, environment.height)
	defer shd.destroy(&shadow_map)
	info, info_error := parse(info_data)
	defer destroy(&info)
	table, table_error := wts.parse(string(strings_data))
	defer wts.destroy(&table)
	if environment_error != .None ||
	   pathing_error != .None ||
	   shadow_error != .None ||
	   info_error != .None ||
	   table_error != .None {
		log.infof(
			"parse failures (w3e %v, wpm %v, shd %v, w3i %v, wts %v): %s",
			environment_error,
			pathing_error,
			shadow_error,
			info_error,
			table_error,
			map_path,
		)
		totals.failed += 1
		return
	}

	// Dimension invariants against the terrain grid. The shd length
	// invariant already gates shd.parse above.
	testing.expect_value(t, pathing_map.width, 4 * (environment.width - 1))
	testing.expect_value(t, pathing_map.height, 4 * (environment.height - 1))

	switch info.version {
	case VERSION_REIGN_OF_CHAOS:
		totals.version_18 += 1
	case VERSION_FROZEN_THRONE:
		totals.version_25 += 1
	}
	references, unresolved := test_check_references(&info, &table)
	totals.trigger_references += references
	totals.unresolved_reference += unresolved
	if unresolved > 0 {
		log.infof("%d unresolved TRIGSTR_ references: %s", unresolved, map_path)
	}
	totals.maps += 1
}

// Parses all five WI-0010 subformats from every stock map. Gated
// because it opens every archive in the corpus.
@(test)
corpus_sweep_all_maps :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	maps_root, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "Maps"})
	defer delete(maps_root)
	if !os.exists(maps_root) {
		log.info("corpus absent, skipping")
		return
	}

	subdirectories := [?]string{"", "Scenario", "FrozenThrone", "FrozenThrone/Scenario", "FrozenThrone/Community"}
	extensions := [?]string{"w3m", "w3x"}
	map_paths := make([dynamic]string)
	defer {
		for map_path in map_paths {
			delete(map_path)
		}
		delete(map_paths)
	}
	for subdirectory in subdirectories {
		for extension in extensions {
			pattern := fmt.aprintf("%s/%s/*.%s", maps_root, subdirectory, extension)
			defer delete(pattern)
			matches, _ := filepath.glob(pattern)
			append(&map_paths, ..matches)
			delete(matches)
		}
	}
	slice.sort(map_paths[:])

	totals: Sweep_Totals
	for map_path in map_paths {
		test_sweep_map(t, map_path, &totals)
	}
	log.infof(
		"sweep: %d maps (%d v18, %d v25), %d failed, %d TRIGSTR_ references, %d unresolved",
		totals.maps,
		totals.version_18,
		totals.version_25,
		totals.failed,
		totals.trigger_references,
		totals.unresolved_reference,
	)
	testing.expect_value(t, totals.failed, 0)
	testing.expect_value(t, totals.unresolved_reference, 0)
	testing.expect(t, totals.maps > 0, "sweep found no maps")
	testing.expect_value(t, totals.maps, totals.version_18 + totals.version_25)
}
