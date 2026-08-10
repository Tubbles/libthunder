package mmp

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

// A two-player map: four gold mines, one neutral building and the two
// start locations, coloured with the stock player colours (red
// 0xFF0303 for player 1, blue 0x0042FF for player 2), which is what
// pins the file's blue-green-red-alpha byte order.
@(test)
corpus_harrow_preview_icons_decode :: proc(t: ^testing.T) {
	full_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "Maps", "(2)Harrow.w3m"})
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

	data, read_error := mpq.read_file(archive, "war3map.mmp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	preview_icons, error := parse(data)
	defer destroy(&preview_icons)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, preview_icons.version, i32(SUPPORTED_VERSION))
	testing.expect_value(t, len(preview_icons.icons), 7)

	testing.expect_value(t, preview_icons.icons[0].type, i32(ICON_TYPE_GOLD_MINE))
	testing.expect_value(t, preview_icons.icons[0].x, i32(24))
	testing.expect_value(t, preview_icons.icons[0].y, i32(21))
	testing.expect_value(t, preview_icons.icons[0].color_bgra, [4]u8{255, 255, 255, 255})
	testing.expect_value(t, preview_icons.icons[2].type, i32(ICON_TYPE_NEUTRAL_BUILDING))
	testing.expect_value(t, preview_icons.icons[2].x, i32(128))
	testing.expect_value(t, preview_icons.icons[2].y, i32(137))
	testing.expect_value(t, preview_icons.icons[5].type, i32(ICON_TYPE_PLAYER_START_LOCATION))
	testing.expect_value(t, preview_icons.icons[5].x, i32(220))
	testing.expect_value(t, preview_icons.icons[5].y, i32(223))
	testing.expect_value(t, preview_icons.icons[5].color_bgra, [4]u8{0x03, 0x03, 0xFF, 0xFF})
	testing.expect_value(t, preview_icons.icons[6].type, i32(ICON_TYPE_PLAYER_START_LOCATION))
	testing.expect_value(t, preview_icons.icons[6].x, i32(39))
	testing.expect_value(t, preview_icons.icons[6].y, i32(42))
	testing.expect_value(t, preview_icons.icons[6].color_bgra, [4]u8{0xFF, 0x42, 0x00, 0xFF})
}
