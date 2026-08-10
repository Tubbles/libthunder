package wts

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python reader over the
// extracted members (WI-0010 log, 2026-08-10), not with this parser.

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

@(private)
test_read_trigger_strings :: proc(t: ^testing.T, map_path: []string) -> (table: Trigger_Strings, available: bool) {
	full_path, _ := filepath.join(map_path)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return {}, false
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	if open_error != .None {
		return {}, false
	}
	defer mpq.close(archive)
	data, read_error := mpq.read_file(archive, "war3map.wts")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	parsed, parse_error := parse(string(data))
	testing.expect_value(t, parse_error, Error.None)
	return parsed, true
}

@(test)
corpus_booty_bay_resolves :: proc(t: ^testing.T) {
	table, available := test_read_trigger_strings(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)BootyBay.w3m"},
	)
	if !available {
		return
	}
	defer destroy(&table)

	name, name_found := lookup(&table, 3)
	testing.expect_value(t, name_found, true)
	testing.expect_value(t, name, "Booty Bay")
	testing.expect_value(t, resolve(&table, "TRIGSTR_006"), "Blizzard Entertainment")
	testing.expect_value(t, resolve(&table, "TRIGSTR_004"), "1v1")
	testing.expect_value(t, resolve(&table, "TRIGSTR_000"), "Player 1")
	testing.expect_value(t, resolve(&table, "TRIGSTR_002"), "Force 1")
}

@(test)
corpus_echo_isles_resolves :: proc(t: ^testing.T) {
	table, available := test_read_trigger_strings(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(2)EchoIsles.w3x"},
	)
	if !available {
		return
	}
	defer destroy(&table)

	name, name_found := lookup(&table, 4)
	testing.expect_value(t, name_found, true)
	testing.expect_value(t, name, "Echo Isles")
	testing.expect_value(t, resolve(&table, "TRIGSTR_005"), "1v1")
	testing.expect_value(t, resolve(&table, "TRIGSTR_001"), "Player 1")
}
