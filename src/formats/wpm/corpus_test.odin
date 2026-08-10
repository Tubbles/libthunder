package wpm

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (WI-0010 log, 2026-08-10), not with this
// parser. The dimension invariant against the same map's w3e grid is
// asserted here for the two spot-check maps and for every corpus map
// in the sweep (thunder:formats/w3i corpus test).

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
	cell_checks: [][3]u32, // x, y, expected flag byte
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

	pathing_data, pathing_error := mpq.read_file(archive, "war3map.wpm")
	defer delete(pathing_data)
	testing.expect_value(t, pathing_error, mpq.Error.None)
	pathing_map, parse_error := parse(pathing_data)
	defer destroy(&pathing_map)
	testing.expect_value(t, parse_error, Error.None)
	testing.expect_value(t, pathing_map.width, expected_width)
	testing.expect_value(t, pathing_map.height, expected_height)
	for check in cell_checks {
		testing.expect_value(t, cell(&pathing_map, int(check[0]), int(check[1])), u8(check[2]))
	}

	// Dimension invariant against the same map's terrain grid.
	environment_data, environment_read_error := mpq.read_file(archive, "war3map.w3e")
	defer delete(environment_data)
	testing.expect_value(t, environment_read_error, mpq.Error.None)
	environment, environment_error := w3e.parse(environment_data)
	defer w3e.destroy(&environment)
	testing.expect_value(t, environment_error, w3e.Error.None)
	testing.expect_value(t, pathing_map.width, 4 * (environment.width - 1))
	testing.expect_value(t, pathing_map.height, 4 * (environment.height - 1))
}

@(test)
corpus_booty_bay_decodes :: proc(t: ^testing.T) {
	cell_checks := [][3]u32{{0, 0, 0xCE}, {100, 50, 0xCE}, {300, 200, 0x0A}}
	test_check_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)BootyBay.w3m"},
		768,
		384,
		cell_checks,
	)
}

@(test)
corpus_echo_isles_decodes :: proc(t: ^testing.T) {
	cell_checks := [][3]u32{{0, 0, 0xCE}, {100, 50, 0x08}, {300, 200, 0x40}}
	test_check_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(2)EchoIsles.w3x"},
		512,
		384,
		cell_checks,
	)
}
