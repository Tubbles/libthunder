package slk

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

// End-to-end validation: extract the real gameplay tables from
// War3.mpq with the MPQ reader and parse them. Skips without data/.

@(private = "file")
war3_archive_path :: proc() -> string {
	path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	return path
}

@(test)
corpus_unit_tables_parse :: proc(t: ^testing.T) {
	archive_path := war3_archive_path()
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	table_names := [?]string{
		"Units\\UnitData.slk",
		"Units\\UnitBalance.slk",
		"Units\\UnitWeapons.slk",
		"Units\\UnitAbilities.slk",
		"Units\\UnitUI.slk",
	}
	for table_name in table_names {
		content, read_error := mpq.read_file(archive, table_name)
		defer delete(content)
		testing.expect_value(t, read_error, mpq.Error.None)
		if read_error != .None {
			continue
		}

		table, parse_error := parse(string(content))
		defer destroy(&table)
		testing.expect_value(t, parse_error, Error.None)
		testing.expect(t, table.column_count > 1, "table has no columns")
		testing.expect(t, table.row_count > 10, "table implausibly short")

		// Every gameplay unit table keys rows on the unit type ID; the
		// footman must be somewhere in the first column.
		found_footman := false
		for row in 1 ..< table.row_count {
			text, is_string := cell_text(&table, row, 0)
			if is_string && text == "hfoo" {
				found_footman = true
				break
			}
		}
		testing.expectf(t, found_footman, "no hfoo row in %s", table_name)
		log.infof("%s: %d columns, %d rows", table_name, table.column_count, table.row_count)
	}
}
