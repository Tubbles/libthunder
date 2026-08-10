package w3e

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (WI-0010 log, 2026-08-10), not with this
// parser.

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

@(private)
test_read_member :: proc(t: ^testing.T, map_path: []string, member_name: string) -> (data: []u8, available: bool) {
	full_path, _ := filepath.join(map_path)
	defer delete(full_path)
	if !os.exists(full_path) {
		log.info("corpus absent, skipping")
		return nil, false
	}
	archive, open_error := mpq.open(full_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	if open_error != .None {
		return nil, false
	}
	defer mpq.close(archive)
	member, read_error := mpq.read_file(archive, member_name)
	testing.expect_value(t, read_error, mpq.Error.None)
	if read_error != .None {
		delete(member)
		return nil, false
	}
	return member, true
}

@(test)
corpus_booty_bay_decodes :: proc(t: ^testing.T) {
	data, available := test_read_member(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)BootyBay.w3m"},
		"war3map.w3e",
	)
	if !available {
		return
	}
	defer delete(data)

	environment, error := parse(data)
	defer destroy(&environment)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, environment.tileset, 'L')
	testing.expect_value(t, environment.is_custom_tileset, false)
	testing.expect_value(t, len(environment.ground_tileset_ids), 6)
	testing.expect_value(t, environment.ground_tileset_ids[0], [4]u8{'L', 'd', 'r', 't'})
	testing.expect_value(t, environment.ground_tileset_ids[5], [4]u8{'L', 'g', 'r', 'd'})
	testing.expect_value(t, len(environment.cliff_tileset_ids), 2)
	testing.expect_value(t, environment.cliff_tileset_ids[0], [4]u8{'C', 'L', 'd', 'i'})
	testing.expect_value(t, environment.width, 193)
	testing.expect_value(t, environment.height, 97)
	testing.expect_value(t, environment.left, -12544)
	testing.expect_value(t, environment.bottom, -6400)
	testing.expect_value(t, len(environment.tilepoints), 18721)

	corner := tilepoint(&environment, 0, 0)
	testing.expect_value(t, corner.ground_height, 8192)
	testing.expect_value(t, corner.water_level, 8192)
	testing.expect_value(t, corner.edge_flag, true)
	testing.expect_value(t, corner.ground_texture, 4)
	testing.expect_value(t, corner.flags, Tilepoint_Flags{.Boundary})
	testing.expect_value(t, corner.variation, 9)
	testing.expect_value(t, corner.cliff_variation, 12)
	testing.expect_value(t, corner.cliff_level, 6)
	testing.expect_value(t, corner.cliff_texture, 1)

	interior := tilepoint(&environment, 96, 48)
	testing.expect_value(t, interior.ground_height, 9270)
	testing.expect_value(t, interior.water_level, 9216)
	testing.expect_value(t, interior.edge_flag, false)
	testing.expect_value(t, interior.ground_texture, 3)
	testing.expect_value(t, interior.flags, Tilepoint_Flags{})
	testing.expect_value(t, interior.variation, 0)
	testing.expect_value(t, interior.cliff_variation, 13)
	testing.expect_value(t, interior.cliff_level, 3)
	testing.expect_value(t, interior.cliff_texture, 1)
}

@(test)
corpus_echo_isles_decodes :: proc(t: ^testing.T) {
	data, available := test_read_member(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "FrozenThrone", "(2)EchoIsles.w3x"},
		"war3map.w3e",
	)
	if !available {
		return
	}
	defer delete(data)

	environment, error := parse(data)
	defer destroy(&environment)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, environment.width, 129)
	testing.expect_value(t, environment.height, 97)
	testing.expect_value(t, environment.left, -8192)
	testing.expect_value(t, environment.bottom, -6144)

	corner := tilepoint(&environment, 0, 0)
	testing.expect_value(t, corner.ground_height, 8088)
	testing.expect_value(t, corner.water_level, 9728)
	testing.expect_value(t, corner.edge_flag, true)
	testing.expect_value(t, corner.ground_texture, 0)
	testing.expect_value(t, corner.flags, Tilepoint_Flags{.Water})
	testing.expect_value(t, corner.variation, 1)
	testing.expect_value(t, corner.cliff_variation, 1)
	testing.expect_value(t, corner.cliff_level, 4)
	testing.expect_value(t, corner.cliff_texture, 15)

	interior := tilepoint(&environment, 96, 48)
	testing.expect_value(t, interior.ground_height, 8451)
	testing.expect_value(t, interior.water_level, 9728)
	testing.expect_value(t, interior.ground_texture, 3)
	testing.expect_value(t, interior.flags, Tilepoint_Flags{.Water})
	testing.expect_value(t, interior.variation, 4)
	testing.expect_value(t, interior.cliff_level, 4)
}
