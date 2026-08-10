package w3c

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (tmp/wi0012_leaf_probe.py, WI-0012), not with
// these parsers.
//
// This file also hosts the sweep over all three WI-0012 leaf formats
// (gated behind THUNDER_CORPUS_SWEEP=1). It lives in this package so
// the sweep exists once rather than three times; w3c is the format
// whose record shape the sweep most needs to keep honest, since its
// only guard against the unsignaled Reforged camera layout is that
// every file ends exactly where the classic shape says it should.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import mmp "thunder:formats/mmp"
import mpq "thunder:formats/mpq"
import w3r "thunder:formats/w3r"

@(private)
test_open_corpus_map :: proc(t: ^testing.T, map_path: []string) -> (archive: ^mpq.Archive, ok: bool) {
	full_path, _ := filepath.join(map_path)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return nil, false
	}
	open_error: mpq.Error
	archive, open_error = mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	return archive, open_error == .None
}

@(test)
corpus_wetlands_cameras_decode :: proc(t: ^testing.T) {
	archive, ok := test_open_corpus_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(4)Wetlands.w3x"},
	)
	if !ok {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3c")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	map_cameras, error := parse(data)
	defer destroy(&map_cameras)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_cameras.version, i32(SUPPORTED_VERSION))
	testing.expect_value(t, len(map_cameras.cameras), 4)

	// All four cameras share a target and differ mainly by rotation.
	testing.expect_value(t, map_cameras.cameras[0].name, "east")
	testing.expect_value(t, map_cameras.cameras[0].target_x, f32(45.51))
	testing.expect_value(t, map_cameras.cameras[0].target_y, f32(1410.85))
	testing.expect_value(t, map_cameras.cameras[0].rotation, f32(0))
	testing.expect_value(t, map_cameras.cameras[0].angle_of_attack, f32(304))
	testing.expect_value(t, map_cameras.cameras[0].distance, f32(1650))
	testing.expect_value(t, map_cameras.cameras[0].field_of_view, f32(70))
	testing.expect_value(t, map_cameras.cameras[0].far_clipping_plane, f32(5000))
	testing.expect_value(t, map_cameras.cameras[0].near_clipping_plane, f32(100))
	testing.expect_value(t, map_cameras.cameras[1].name, "north")
	testing.expect_value(t, map_cameras.cameras[1].rotation, f32(90))
	testing.expect_value(t, map_cameras.cameras[2].name, "west")
	testing.expect_value(t, map_cameras.cameras[2].rotation, f32(180))
	testing.expect_value(t, map_cameras.cameras[2].distance, f32(3386))
	testing.expect_value(t, map_cameras.cameras[3].name, "South")
	testing.expect_value(t, map_cameras.cameras[3].rotation, f32(270))
	testing.expect_value(t, map_cameras.cameras[3].distance, f32(3000))
}

// 176 of the 186 stock maps ship an eight-byte w3c holding no cameras
// at all; only 10 maps define any.
@(test)
corpus_harrow_has_no_cameras :: proc(t: ^testing.T) {
	archive, ok := test_open_corpus_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)Harrow.w3m"},
	)
	if !ok {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3c")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	testing.expect_value(t, len(data), 8)
	map_cameras, error := parse(data)
	defer destroy(&map_cameras)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(map_cameras.cameras), 0)
}

@(private)
Sweep_Totals :: struct {
	maps:     int,
	cameras:  int,
	regions:  int,
	icons:    int,
	missing:  int,
	failed:   int,
}

@(private)
test_sweep_archive :: proc(archive: ^mpq.Archive, archive_label: string, totals: ^Sweep_Totals) {
	camera_data, camera_read_error := mpq.read_file(archive, "war3map.w3c")
	defer delete(camera_data)
	if camera_read_error != .None {
		log.infof("war3map.w3c missing (%v): %s", camera_read_error, archive_label)
		totals.missing += 1
	} else {
		map_cameras, error := parse(camera_data)
		defer destroy(&map_cameras)
		if error != .None {
			log.infof("w3c parse failure (%v): %s", error, archive_label)
			totals.failed += 1
		} else {
			totals.cameras += len(map_cameras.cameras)
		}
	}

	region_data, region_read_error := mpq.read_file(archive, "war3map.w3r")
	defer delete(region_data)
	if region_read_error != .None {
		log.infof("war3map.w3r missing (%v): %s", region_read_error, archive_label)
		totals.missing += 1
	} else {
		map_regions, error := w3r.parse(region_data)
		defer w3r.destroy(&map_regions)
		if error != .None {
			log.infof("w3r parse failure (%v): %s", error, archive_label)
			totals.failed += 1
		} else {
			totals.regions += len(map_regions.regions)
		}
	}

	icon_data, icon_read_error := mpq.read_file(archive, "war3map.mmp")
	defer delete(icon_data)
	if icon_read_error != .None {
		log.infof("war3map.mmp missing (%v): %s", icon_read_error, archive_label)
		totals.missing += 1
	} else {
		preview_icons, error := mmp.parse(icon_data)
		defer mmp.destroy(&preview_icons)
		if error != .None {
			log.infof("mmp parse failure (%v): %s", error, archive_label)
			totals.failed += 1
		} else {
			totals.icons += len(preview_icons.icons)
		}
	}
}

// Parses war3map.w3c, war3map.w3r and war3map.mmp out of every stock
// map. Gated because it opens every archive in the corpus.
@(test)
corpus_sweep_all_leaf_formats :: proc(t: ^testing.T) {
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
	for map_path in map_paths {
		archive, open_error := mpq.open(map_path)
		if open_error != .None {
			log.infof("open failed (%v): %s", open_error, map_path)
			totals.failed += 1
			continue
		}
		defer mpq.close(archive)
		totals.maps += 1
		test_sweep_archive(archive, map_path, &totals)
	}

	log.infof(
		"sweep: %d maps, %d cameras, %d regions, %d preview icons, %d members missing, %d failed",
		totals.maps,
		totals.cameras,
		totals.regions,
		totals.icons,
		totals.missing,
		totals.failed,
	)
	testing.expect(t, totals.maps > 0, "sweep found no maps")
	testing.expect_value(t, totals.missing, 0)
	testing.expect_value(t, totals.failed, 0)
}
