package shd

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values (byte counts, shadowed-sample totals, first shadowed index)
// were derived with an independent Python struct reader over the
// extracted members (WI-0010 log, 2026-08-10), not with this parser.
// The corpus-wide length invariant is asserted for every map in the
// sweep (thunder:formats/w3i corpus test).

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"
import w3e "thunder:formats/w3e"

@(private)
test_check_map :: proc(
	t: ^testing.T,
	map_path: []string,
	expected_width: u32,
	expected_height: u32,
	expected_shadowed_count: int,
	expected_first_shadowed_index: int,
) {
	full_path, _ := filepath.join(map_path)
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

	environment_data, environment_read_error := mpq.read_file(archive, "war3map.w3e")
	defer delete(environment_data)
	testing.expect_value(t, environment_read_error, mpq.Error.None)
	environment, environment_error := w3e.parse(environment_data)
	defer w3e.destroy(&environment)
	testing.expect_value(t, environment_error, w3e.Error.None)

	shadow_data, shadow_read_error := mpq.read_file(archive, "war3map.shd")
	defer delete(shadow_data)
	testing.expect_value(t, shadow_read_error, mpq.Error.None)
	shadow_map, parse_error := parse(shadow_data, environment.width, environment.height)
	defer destroy(&shadow_map)
	testing.expect_value(t, parse_error, Error.None)
	testing.expect_value(t, shadow_map.width, expected_width)
	testing.expect_value(t, shadow_map.height, expected_height)

	shadowed_count := 0
	first_shadowed_index := -1
	for value, index in shadow_map.samples {
		if value == SHADOWED {
			shadowed_count += 1
			if first_shadowed_index < 0 {
				first_shadowed_index = index
			}
		} else if value != 0 {
			testing.fail_now(t, "corpus shadow maps contain only 0x00 and 0xFF")
		}
	}
	testing.expect_value(t, shadowed_count, expected_shadowed_count)
	testing.expect_value(t, first_shadowed_index, expected_first_shadowed_index)
}

@(test)
corpus_booty_bay_decodes :: proc(t: ^testing.T) {
	test_check_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)BootyBay.w3m"},
		768,
		384,
		27314,
		20491,
	)
}

@(test)
corpus_echo_isles_decodes :: proc(t: ^testing.T) {
	test_check_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(2)EchoIsles.w3x"},
		512,
		384,
		7913,
		8669,
	)
}
