package object_data

// Corpus tests against the stock maps and demo campaign in the
// git-ignored data/ directory; skipped cleanly when the corpus is
// absent. Reference values were derived with an independent Python
// struct reader over the extracted members (tmp/object_reader.py,
// WI-0011 log), not with this parser.
//
// The gated sweep (THUNDER_CORPUS_SWEEP=1) parses every object-data
// file in the corpus: all seven war3map.* members across the 186
// stock maps, the war3campaign.* members of DemoCampaign.w3n, and
// the war3map.* members of the campaign's three embedded maps
// (extracted to tmp/ and opened as archives). Every file must parse
// to exact end-of-file.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"
import mpq "thunder:formats/mpq"

@(private)
OBJECT_EXTENSIONS :: [?]string{"w3u", "w3t", "w3b", "w3d", "w3a", "w3h", "w3q"}

// The campaign's unit data, the simple shape: war3campaign.w3u from
// DemoCampaign.w3n, format v1.
@(test)
corpus_demo_campaign_w3u_decodes :: proc(t: ^testing.T) {
	full_path, _ := filepath.join(
		{#directory, "..", "..", "..", "data", "Warcraft III", "Campaigns", "DemoCampaign.w3n"},
	)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3campaign.w3u")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	object_data, error := parse(data, .Simple)
	defer destroy(&object_data)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, object_data.version, 1)
	testing.expect_value(t, len(object_data.original), 6)
	testing.expect_value(t, len(object_data.custom), 2)

	// A one-modification original entry whose end token repeats the
	// entry's old id.
	first := object_data.original[0]
	testing.expect_value(t, first.old_id, [4]u8{'h', 'm', 'p', 'r'})
	testing.expect_value(t, first.new_id, [4]u8{})
	testing.expect_value(t, len(first.modifications), 1)
	testing.expect_value(t, first.modifications[0].id, [4]u8{'u', 'v', 'e', 'r'})
	testing.expect_value(t, first.modifications[0].value_type, Value_Type.Integer)
	testing.expect_value(t, first.modifications[0].value.(i32), 0)
	testing.expect_value(t, first.modifications[0].end_token, first.old_id)

	third := object_data.original[2]
	testing.expect_value(t, third.old_id, [4]u8{'n', 'm', 's', 'c'})
	testing.expect_value(t, len(third.modifications), 53)
	testing.expect_value(t, third.modifications[0].id, [4]u8{'u', 'n', 'a', 'm'})
	testing.expect_value(t, third.modifications[0].value_type, Value_Type.String)
	testing.expect_value(t, third.modifications[0].value.(string), "TRIGSTR_037")

	// A custom entry deriving a new unit from a standard one, with
	// zero end tokens.
	custom := object_data.custom[0]
	testing.expect_value(t, custom.old_id, [4]u8{'N', 'n', 'g', 's'})
	testing.expect_value(t, custom.new_id, [4]u8{'N', '0', '0', '0'})
	testing.expect_value(t, len(custom.modifications), 67)
	testing.expect_value(t, custom.modifications[1].id, [4]u8{'u', 'c', 'a', 'm'})
	testing.expect_value(t, custom.modifications[1].value_type, Value_Type.Integer)
	testing.expect_value(t, custom.modifications[1].value.(i32), 1)
	testing.expect_value(t, custom.modifications[1].end_token, [4]u8{})
	testing.expect_value(t, object_data.custom[1].new_id, [4]u8{'N', '0', '0', '1'})
}

// A map's ability data, the leveled shape: war3map.w3a from
// (4)Monolith.w3x, the corpus's only leveled v1 file.
@(test)
corpus_monolith_w3a_decodes :: proc(t: ^testing.T) {
	full_path, _ := filepath.join(
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "Scenario", "(4)Monolith.w3x"},
	)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3a")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	object_data, error := parse(data, .Leveled)
	defer destroy(&object_data)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, object_data.version, 1)
	testing.expect_value(t, len(object_data.original), 2)
	testing.expect_value(t, len(object_data.custom), 7)

	first := object_data.original[0]
	testing.expect_value(t, first.old_id, [4]u8{'A', 'C', 'w', 'e'})
	testing.expect_value(t, len(first.modifications), 4)
	testing.expect_value(t, first.modifications[0].id, [4]u8{'a', 'r', 'l', 'v'})
	testing.expect_value(t, first.modifications[0].value_type, Value_Type.Integer)
	testing.expect_value(t, first.modifications[0].value.(i32), 6)
	testing.expect_value(t, first.modifications[0].level, 0)
	testing.expect_value(t, first.modifications[0].data_pointer, 0)
	testing.expect_value(t, first.modifications[0].end_token, first.old_id)

	// A per-level modification: the same field id at level 3.
	second := object_data.original[1]
	testing.expect_value(t, second.old_id, [4]u8{'A', 'N', 'w', 'm'})
	testing.expect_value(t, len(second.modifications), 6)
	testing.expect_value(t, second.modifications[1].id, [4]u8{'a', 'u', 'b', '1'})
	testing.expect_value(t, second.modifications[1].value_type, Value_Type.String)
	testing.expect_value(t, second.modifications[1].value.(string), "TRIGSTR_166")
	testing.expect_value(t, second.modifications[1].level, 3)
	testing.expect_value(t, second.modifications[1].data_pointer, 0)

	custom := object_data.custom[0]
	testing.expect_value(t, custom.old_id, [4]u8{'A', 'I', 'g', 'o'})
	testing.expect_value(t, custom.new_id, [4]u8{'A', '0', '0', '0'})
	testing.expect_value(t, len(custom.modifications), 11)
}

@(private)
Sweep_Totals :: struct {
	files:         int,
	failed:        int,
	version_1:     int,
	version_2:     int,
	per_extension: [len(OBJECT_EXTENSIONS)]int,
}

// Tries every object-data member of an archive with the given member
// prefix ("war3map" or "war3campaign") and parses each one found.
@(private)
test_sweep_archive :: proc(archive: ^mpq.Archive, archive_label: string, totals: ^Sweep_Totals) {
	extensions := OBJECT_EXTENSIONS
	for extension, extension_index in extensions {
		prefix := "war3map"
		if strings.has_suffix(archive_label, ".w3n") {
			prefix = "war3campaign"
		}
		member_name := fmt.aprintf("%s.%s", prefix, extension)
		defer delete(member_name)
		data, read_error := mpq.read_file(archive, member_name)
		defer delete(data)
		if read_error != .None {
			continue
		}
		shape, known := shape_for_extension(extension)
		if !known {
			totals.failed += 1
			continue
		}
		object_data, error := parse(data, shape)
		if error != .None {
			log.infof("parse failure (%v): %s %s", error, archive_label, member_name)
			totals.failed += 1
			continue
		}
		switch object_data.version {
		case 1:
			totals.version_1 += 1
		case 2:
			totals.version_2 += 1
		}
		totals.per_extension[extension_index] += 1
		totals.files += 1
		destroy(&object_data)
	}
}

// Extracts the campaign's embedded maps to tmp/ and sweeps their
// object data too (mpq.open reads from a path, so the members are
// staged on disk first).
@(private)
test_sweep_embedded_maps :: proc(campaign: ^mpq.Archive, tmp_root: string, totals: ^Sweep_Totals) {
	listfile_data, listfile_error := mpq.read_file(campaign, "(listfile)")
	defer delete(listfile_data)
	if listfile_error != .None {
		log.infof("campaign listfile unreadable: %v", listfile_error)
		totals.failed += 1
		return
	}
	listfile_text := string(listfile_data)
	for line in strings.split_lines_iterator(&listfile_text) {
		member := strings.trim_space(line)
		if !strings.has_suffix(member, ".w3x") && !strings.has_suffix(member, ".w3m") {
			continue
		}
		embedded_data, embedded_error := mpq.read_file(campaign, member)
		defer delete(embedded_data)
		if embedded_error != .None {
			log.infof("embedded map unreadable (%v): %s", embedded_error, member)
			totals.failed += 1
			continue
		}
		staged_path := fmt.aprintf("%s/object_sweep_%s", tmp_root, member)
		defer delete(staged_path)
		if write_error := os.write_entire_file(staged_path, embedded_data); write_error != nil {
			log.infof("staging failed (%v): %s", write_error, staged_path)
			totals.failed += 1
			continue
		}
		embedded_archive, embedded_open_error := mpq.open(staged_path)
		if embedded_open_error != .None {
			log.infof("embedded map open failed (%v): %s", embedded_open_error, member)
			totals.failed += 1
			continue
		}
		defer mpq.close(embedded_archive)
		test_sweep_archive(embedded_archive, member, totals)
	}
}

// Parses every object-data file in the corpus. Gated because it
// opens every archive in the corpus.
@(test)
corpus_sweep_all_object_data :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	data_root, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III"})
	defer delete(data_root)
	tmp_root, _ := filepath.join({#directory, "..", "..", "..", "tmp"})
	defer delete(tmp_root)
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
		test_sweep_archive(archive, map_path, &totals)
	}

	campaign_path, _ := filepath.join({data_root, "Campaigns", "DemoCampaign.w3n"})
	defer delete(campaign_path)
	campaign, campaign_error := mpq.open(campaign_path)
	if campaign_error != .None {
		log.infof("campaign open failed: %v", campaign_error)
		totals.failed += 1
	} else {
		defer mpq.close(campaign)
		test_sweep_archive(campaign, campaign_path, &totals)
		test_sweep_embedded_maps(campaign, tmp_root, &totals)
	}

	extensions := OBJECT_EXTENSIONS
	for extension, extension_index in extensions {
		log.infof("%s: %d files", extension, totals.per_extension[extension_index])
	}
	log.infof(
		"sweep: %d maps opened, %d object files (%d v1, %d v2), %d failed",
		maps_opened,
		totals.files,
		totals.version_1,
		totals.version_2,
		totals.failed,
	)
	testing.expect_value(t, totals.failed, 0)
	testing.expect(t, totals.files > 0, "sweep found no object data")
	testing.expect_value(t, totals.files, totals.version_1 + totals.version_2)
	// The corpus contents are fixed, so the exact counts are asserted:
	// a drop here means enumeration or extraction regressed and files
	// silently left the sweep's coverage, not that the corpus changed.
	testing.expect_value(t, totals.files, 61)
	testing.expect_value(t, totals.version_1, 13)
	testing.expect_value(t, totals.version_2, 48)
	expected_per_extension := [?]int{15, 13, 7, 7, 9, 7, 3}
	for expected, extension_index in expected_per_extension {
		testing.expect_value(t, totals.per_extension[extension_index], expected)
	}
}
