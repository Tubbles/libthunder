package mpq

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

// Corpus tests against the real 1.29.2 archives pinned in
// docs/asset-manifest.md. They skip (pass with a log line) when the
// git-ignored data/ directory is absent, so CI stays hermetic.

@(private = "file")
corpus_path :: proc(file_parts: ..string) -> string {
	parts := make([dynamic]string)
	defer delete(parts)
	append(&parts, #directory, "..", "..", "..", "data", "Warcraft III")
	append(&parts, ..file_parts)
	path, _ := filepath.join(parts[:])
	return path
}

@(test)
corpus_war3_mpq_tables_parse :: proc(t: ^testing.T) {
	path := corpus_path("War3.mpq")
	defer delete(path)
	if !os.exists(path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	defer close(archive)

	testing.expect(t, len(archive.hash_table) >= 1024, "suspiciously small hash table")
	testing.expect(t, len(archive.block_table) >= 1024, "suspiciously small block table")
}

@(test)
corpus_war3_mpq_extracts_common_j :: proc(t: ^testing.T) {
	path := corpus_path("War3.mpq")
	defer delete(path)
	if !os.exists(path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	defer close(archive)

	script, read_error := read_file(archive, "Scripts\\common.j")
	defer delete(script)
	testing.expect_value(t, read_error, Error.None)
	testing.expect(t, len(script) > 100_000, "common.j implausibly small")
	testing.expect(t, strings.contains(string(script), "native "), "common.j lacks native declarations")
}

@(test)
corpus_war3_mpq_extracts_listfile :: proc(t: ^testing.T) {
	path := corpus_path("War3.mpq")
	defer delete(path)
	if !os.exists(path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	defer close(archive)

	listfile, read_error := read_file(archive, "(listfile)")
	defer delete(listfile)
	testing.expect_value(t, read_error, Error.None)
	testing.expect(t, strings.contains(string(listfile), "common.j"), "listfile lacks common.j")
}

@(test)
corpus_stock_map_opens :: proc(t: ^testing.T) {
	path := corpus_path("Maps", "(2)BootyBay.w3m")
	defer delete(path)
	if !os.exists(path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	defer close(archive)

	// Maps wrap the archive behind the 512-byte HM3W block.
	testing.expect_value(t, archive.archive_offset, i64(512))

	map_info, read_error := read_file(archive, "war3map.w3i")
	defer delete(map_info)
	testing.expect_value(t, read_error, Error.None)
	testing.expect(t, len(map_info) > 0)
}

// Full decompression sweep over every listfile entry of every archive
// in the manifest. Slow (reads the whole GB-scale corpus), so it only
// runs when THUNDER_CORPUS_SWEEP=1.
@(test)
corpus_full_sweep :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	archive_names := [?]string{"War3.mpq", "War3x.mpq", "War3xLocal.mpq", "War3Local.mpq", "Deprecated.mpq"}
	for archive_name in archive_names {
		path := corpus_path(archive_name)
		defer delete(path)
		if !os.exists(path) {
			log.infof("%s absent, skipping", archive_name)
			continue
		}

		archive, open_error := open(path)
		testing.expect_value(t, open_error, Error.None)
		if open_error != .None {
			continue
		}
		defer close(archive)

		listfile, listfile_error := read_file(archive, "(listfile)")
		defer delete(listfile)
		testing.expect_value(t, listfile_error, Error.None)
		if listfile_error != .None {
			continue
		}

		extracted_count := 0
		failed_count := 0
		unsupported_count := 0
		missing_count := 0
		listfile_text := string(listfile)
		for line in strings.split_lines_iterator(&listfile_text) {
			file_name := strings.trim_space(line)
			if len(file_name) == 0 {
				continue
			}
			data, read_error := read_file(archive, file_name)
			switch read_error {
			case .None:
				extracted_count += 1
			case .File_Not_Found:
				missing_count += 1
			case .Unsupported_Compression:
				unsupported_count += 1
				if unsupported_count <= 20 {
					log.infof("%s: unsupported compression: %s", archive_name, file_name)
				}
			case .Cannot_Open_File, .No_Archive_Header, .Invalid_Table, .Read_Failed,
			     .Corrupt_Sector_Table, .Decompression_Failed, .Size_Mismatch:
				failed_count += 1
				if failed_count <= 20 {
					log.infof("%s: %v: %s", archive_name, read_error, file_name)
				}
			}
			delete(data)
		}
		log.infof(
			"%s: extracted %d, missing %d, unsupported %d, failed %d",
			archive_name,
			extracted_count,
			missing_count,
			unsupported_count,
			failed_count,
		)
		testing.expect_value(t, failed_count, 0)
		testing.expect(t, extracted_count > 0, "sweep extracted nothing")
	}
}
