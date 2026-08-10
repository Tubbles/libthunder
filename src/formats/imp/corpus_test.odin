package imp

// Corpus spot-checks against stock maps and the demo campaign in the
// git-ignored data/ directory; skipped cleanly when the corpus is
// absent. Reference values were derived with an independent Python
// struct reader over the extracted members (tmp/w3s_imp_reader.py,
// WI-0012 log), not with this parser.
//
// The gated sweep over every imp and w3s file in the corpus lives in
// thunder:formats/w3s, so the two formats are swept together.

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

// A map's import manifest, mixing both corpus-observed flags values.
@(test)
corpus_monolith_imp_decodes :: proc(t: ^testing.T) {
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

	data, read_error := mpq.read_file(archive, "war3map.imp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	imported_files, error := parse(data)
	defer destroy(&imported_files)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, imported_files.version, SUPPORTED_VERSION)
	testing.expect_value(t, len(imported_files.files), 22)

	// The map preview: a full custom path, stored in the archive under
	// exactly this name.
	testing.expect_value(t, imported_files.files[0].flags, FLAGS_CUSTOM_PATH)
	testing.expect_value(t, imported_files.files[0].path, "war3mapPreview.tga")
	// An AI script: stored under the archive's import directory.
	testing.expect_value(t, imported_files.files[1].flags, FLAGS_STANDARD_PATH)
	testing.expect_value(t, imported_files.files[1].path, "Lizard_AI.wai")
	testing.expect_value(t, imported_files.files[21].flags, FLAGS_CUSTOM_PATH)
	testing.expect_value(t, imported_files.files[21].path, "LoadingScreenTR.tga")
}

// The campaign variant: war3campaign.imp out of DemoCampaign.w3n,
// which mpq.open reads directly. Same format, and the flags byte means
// the same thing, except that the import directory the standard-path
// entries resolve against is "war3campImported\" here.
@(test)
corpus_demo_campaign_imp_decodes :: proc(t: ^testing.T) {
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
	if open_error != .None {
		return
	}
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "war3campaign.imp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	imported_files, error := parse(data)
	defer destroy(&imported_files)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, imported_files.version, SUPPORTED_VERSION)
	testing.expect_value(t, len(imported_files.files), 15)

	testing.expect_value(t, imported_files.files[0].flags, FLAGS_STANDARD_PATH)
	testing.expect_value(t, imported_files.files[0].path, "d03_blue.ai")
	testing.expect_value(t, imported_files.files[4].flags, FLAGS_CUSTOM_PATH)
	testing.expect_value(t, imported_files.files[4].path, "Demo-Loading-BotLeft.tga")
	testing.expect_value(t, imported_files.files[14].flags, FLAGS_STANDARD_PATH)
	testing.expect_value(t, imported_files.files[14].path, "DemoLoad05.mdx")
}
