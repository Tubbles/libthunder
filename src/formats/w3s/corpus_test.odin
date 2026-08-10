package w3s

// Corpus spot-checks against the stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (tmp/w3s_imp_reader.py, WI-0012 log), not with
// this parser.
//
// The gated sweep (THUNDER_CORPUS_SWEEP=1) covers both leaf formats of
// this WI-0012 slice, w3s and imp, since they are enumerated from the
// same archives: war3map.w3s and war3map.imp from all 186 stock maps,
// war3campaign.imp from DemoCampaign.w3n, and both members from the
// campaign's three embedded maps (extracted to tmp/ and opened as
// archives). Every file must parse to exact end-of-file.

import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"
import imp "thunder:formats/imp"
import mpq "thunder:formats/mpq"

// A small stock sound table: war3map.w3s from (4)Monolith.w3x, five
// sounds, all of them left at their SLK defaults except for the fade
// rates and the channel.
@(test)
corpus_monolith_w3s_decodes :: proc(t: ^testing.T) {
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
	if open_error != .None {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3s")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	map_sounds, error := parse(data)
	defer destroy(&map_sounds)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_sounds.version, SUPPORTED_VERSION)
	testing.expect_value(t, len(map_sounds.sounds), 5)

	first := map_sounds.sounds[0]
	testing.expect_value(t, first.name, "gg_snd_WispDeath1")
	testing.expect_value(t, first.file_path, "Units\\NightElf\\Wisp\\WispDeath1.wav")
	testing.expect_value(t, first.eax_setting, "DefaultEAXON")
	testing.expect_value(t, first.flags, FLAG_3D_SOUND | FLAG_STOP_WHEN_OUT_OF_RANGE)
	testing.expect_value(t, first.fade_in_rate, 10)
	testing.expect_value(t, first.fade_out_rate, 10)
	testing.expect_value(t, first.volume, UNSET_INTEGER)
	testing.expect_value(t, first.channel, UNSET_INTEGER)
	// The per-type "unset" sentinels: every float field of this record
	// holds 2^32 and every unset-able integer field holds -1.
	testing.expect_value(t, first.pitch, UNSET_FLOAT)
	testing.expect_value(t, first.minimum_distance, UNSET_FLOAT)
	testing.expect_value(t, first.cone_orientation, [3]f32{UNSET_FLOAT, UNSET_FLOAT, UNSET_FLOAT})
	testing.expect_value(t, first.cone_outside_volume, UNSET_INTEGER)

	third := map_sounds.sounds[2]
	testing.expect_value(t, third.name, "gg_snd_ShardDisruptStart")
	testing.expect_value(t, third.file_path, "Abilities\\Spells\\Human\\Flare\\FlareTarget1.wav")
	testing.expect_value(t, third.eax_setting, "SpellsEAX")
	testing.expect_value(t, third.flags, FLAG_STOP_WHEN_OUT_OF_RANGE)
	testing.expect_value(t, third.channel, CHANNEL_GENERAL)

	testing.expect_value(t, map_sounds.sounds[4].name, "gg_snd_ShardDisruptEnd")
}

@(private)
Sweep_Totals :: struct {
	sound_files:  int,
	sounds:       int,
	import_files: int,
	imports:      int,
	failed:       int,
	// Occurrence count per raw imp flags byte value.
	import_flags: [256]int,
}

// Parses the w3s and imp members of one archive, if it has them.
@(private)
test_sweep_archive :: proc(archive: ^mpq.Archive, archive_label: string, prefix: string, totals: ^Sweep_Totals) {
	sound_member := fmt.aprintf("%s.w3s", prefix)
	defer delete(sound_member)
	sound_data, sound_read_error := mpq.read_file(archive, sound_member)
	defer delete(sound_data)
	if sound_read_error == .None {
		map_sounds, error := parse(sound_data)
		defer destroy(&map_sounds)
		if error != .None {
			log.infof("w3s parse failure (%v): %s", error, archive_label)
			totals.failed += 1
		} else {
			totals.sound_files += 1
			totals.sounds += len(map_sounds.sounds)
		}
	}

	import_member := fmt.aprintf("%s.imp", prefix)
	defer delete(import_member)
	import_data, import_read_error := mpq.read_file(archive, import_member)
	defer delete(import_data)
	if import_read_error == .None {
		imported_files, error := imp.parse(import_data)
		defer imp.destroy(&imported_files)
		if error != .None {
			log.infof("imp parse failure (%v): %s", error, archive_label)
			totals.failed += 1
		} else {
			totals.import_files += 1
			totals.imports += len(imported_files.files)
			for file in imported_files.files {
				totals.import_flags[file.flags] += 1
			}
		}
	}
}

// Extracts the campaign's embedded maps to tmp/ and sweeps their leaf
// formats too (mpq.open reads from a path, so members are staged on
// disk first).
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
		staged_path := fmt.aprintf("%s/leaf_sweep_%s", tmp_root, member)
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
		test_sweep_archive(embedded_archive, member, "war3map", totals)
	}
}

// Parses every w3s and imp file in the corpus. Gated because it opens
// every archive in the corpus.
@(test)
corpus_sweep_all_sounds_and_imports :: proc(t: ^testing.T) {
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
		test_sweep_archive(archive, map_path, "war3map", &totals)
	}

	campaign_path, _ := filepath.join({data_root, "Campaigns", "DemoCampaign.w3n"})
	defer delete(campaign_path)
	campaign, campaign_error := mpq.open(campaign_path)
	if campaign_error != .None {
		log.infof("campaign open failed: %v", campaign_error)
		totals.failed += 1
	} else {
		defer mpq.close(campaign)
		test_sweep_archive(campaign, campaign_path, "war3campaign", &totals)
		test_sweep_embedded_maps(campaign, tmp_root, &totals)
	}

	for count, flags in totals.import_flags {
		if count > 0 {
			log.infof("imp flags byte %d: %d entries", flags, count)
		}
	}
	log.infof(
		"sweep: %d maps opened, %d w3s files (%d sounds), %d imp files (%d imports), %d failed",
		maps_opened,
		totals.sound_files,
		totals.sounds,
		totals.import_files,
		totals.imports,
		totals.failed,
	)
	testing.expect_value(t, totals.failed, 0)
	testing.expect(t, totals.sound_files > 0, "sweep found no sound files")
	testing.expect(t, totals.import_files > 0, "sweep found no import manifests")
}
