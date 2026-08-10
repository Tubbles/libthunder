package w3r

// Corpus spot-checks against stock maps in the git-ignored data/
// directory; skipped cleanly when the corpus is absent. Reference
// values were derived with an independent Python struct reader over
// the extracted members (tmp/wi0012_leaf_probe.py, WI-0012), not with
// this parser. The sweep over all three WI-0012 leaf formats lives in
// thunder:formats/w3c.

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

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

// Four snow-weather regions, the corpus example of a populated
// weather id.
@(test)
corpus_harrow_regions_decode :: proc(t: ^testing.T) {
	archive, ok := test_open_corpus_map(
		t,
		{#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)Harrow.w3m"},
	)
	if !ok {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3r")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	map_regions, error := parse(data)
	defer destroy(&map_regions)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, map_regions.version, i32(SUPPORTED_VERSION))
	testing.expect_value(t, len(map_regions.regions), 4)

	testing.expect_value(t, map_regions.regions[0].name, "Snow1")
	testing.expect_value(t, map_regions.regions[0].left, f32(-1024))
	testing.expect_value(t, map_regions.regions[0].bottom, f32(2592))
	testing.expect_value(t, map_regions.regions[0].right, f32(1504))
	testing.expect_value(t, map_regions.regions[0].top, f32(3968))
	testing.expect_value(t, map_regions.regions[0].creation_number, i32(0))
	testing.expect_value(t, map_regions.regions[0].weather_id, [4]u8{'S', 'N', 'h', 's'})
	testing.expect_value(t, map_regions.regions[0].ambient_sound, "")
	testing.expect_value(t, map_regions.regions[0].color_bgra, [4]u8{255, 128, 128, 255})
	testing.expect_value(t, map_regions.regions[3].name, "Snow4")
	testing.expect_value(t, map_regions.regions[3].creation_number, i32(3))
	testing.expect(t, has_weather(map_regions.regions[3]), "weather id not reported")
}

// The corpus example of populated ambient sounds: four regions naming
// war3map.w3s handles, with no weather id.
@(test)
corpus_extreme_candy_war_regions_decode :: proc(t: ^testing.T) {
	archive, ok := test_open_corpus_map(
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
			"Scenario",
			"(10)ExtremeCandyWar2004.w3x",
		},
	)
	if !ok {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3map.w3r")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	map_regions, error := parse(data)
	defer destroy(&map_regions)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(map_regions.regions), 71)

	testing.expect_value(t, map_regions.regions[6].name, "Ambience 1")
	testing.expect_value(t, map_regions.regions[6].ambient_sound, "gg_snd_FreakyForest1")
	testing.expect_value(t, map_regions.regions[6].left, f32(0))
	testing.expect_value(t, map_regions.regions[6].bottom, f32(-96))
	testing.expect_value(t, map_regions.regions[6].right, f32(896))
	testing.expect_value(t, map_regions.regions[6].top, f32(768))
	testing.expect_value(t, map_regions.regions[6].creation_number, i32(10))
	testing.expect(t, !has_weather(map_regions.regions[6]), "zero weather id reported as set")
	testing.expect_value(t, map_regions.regions[6].color_bgra, [4]u8{128, 128, 255, 255})
	testing.expect_value(t, map_regions.regions[3].name, "Alliance GY Fog")
	testing.expect_value(t, map_regions.regions[3].weather_id, [4]u8{'F', 'D', 'w', 'h'})
}
