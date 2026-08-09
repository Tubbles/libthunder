package ini

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

@(test)
corpus_misc_data_parses :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	content, read_error := mpq.read_file(archive, "UI\\MiscData.txt")
	defer delete(content)
	testing.expect_value(t, read_error, mpq.Error.None)

	file := parse(string(content))
	defer destroy(&file)
	testing.expect(t, len(file.sections) > 3, "implausibly few sections")

	// Spot check against a value read off the real 1.29.2 file.
	value, found := lookup(&file, "Misc", "GoldTextColor")
	testing.expect(t, found, "Misc/GoldTextColor missing")
	testing.expect_value(t, value, "255,255,220,0")
	log.infof("UI\\MiscData.txt: %d sections", len(file.sections))
}
