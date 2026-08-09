package mpq

import "core:crypto/sha2"
import "core:encoding/hex"
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

// SHA-256 of extracted content must match an independent decode of
// the same archive by mpyq 0.2.5, a pure-Python MPQ reader (hashes
// recorded 2026-08-09, WI-0006 log). mpyq handles only unencrypted
// zlib or uncompressed files, so the sample spans those storage
// forms; the PKWARE, Huffman, and ADPCM codecs are instead verified
// against reference vectors in their own unit tests.
@(test)
corpus_extraction_matches_external_oracle :: proc(t: ^testing.T) {
	path := corpus_path("War3.mpq")
	defer delete(path)
	if !os.exists(path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	defer close(archive)

	Oracle_Sample :: struct {
		name:            string,
		expected_sha256: string,
	}
	samples := [?]Oracle_Sample {
		{"Scripts\\common.j", "3c21e998bf80d1e04718bd3f2ee7ef2bf1b83359e5b303a56cf59cd61a2afdcd"},
		{"Scripts\\Blizzard.j", "7ca28f0ce47712a9ab6832c22bb0d0c9d2844b5831fb465b9d792731a3d5243e"},
		{"Units\\UnitData.slk", "34a0c8083f146b5d3e25d92a19a8822151d4b26dfe9c1c325a6229466d1b04d6"},
		{"ReplaceableTextures\\Selection\\SelectionCircleLarge.blp", "1b5cb24c47aa63cb91328471e16613e2058449c7494ffbab18a89be8f70eed71"},
		{"UI\\MiscData.txt", "d097d3cbb4a03719a97591900b45ab42fdb847385819c3d5e7dd7b47d7d9b516"},
		{"ReplaceableTextures\\WorldEditUI\\Editor-Toolbar-MapValidation.blp", "6ca051be3831f122c0bb0fc13a823153e359fa5ebb38d955013a63f0e058bce6"},
	}
	for sample in samples {
		content, read_error := read_file(archive, sample.name)
		defer delete(content)
		testing.expect_value(t, read_error, Error.None)

		digest: [sha2.DIGEST_SIZE_256]u8
		digest_context: sha2.Context_256
		sha2.init_256(&digest_context)
		sha2.update(&digest_context, content)
		sha2.final(&digest_context, digest[:])
		digest_hex, _ := hex.encode(digest[:])
		defer delete(digest_hex)
		testing.expectf(
			t,
			string(digest_hex) == sample.expected_sha256,
			"%s: got %s",
			sample.name,
			string(digest_hex),
		)
	}
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
			case .Cannot_Open_File, .No_Archive_Header, .Invalid_Header, .Invalid_Table,
			     .File_Too_Large, .Read_Failed, .Corrupt_Sector_Table, .Decompression_Failed,
			     .Size_Mismatch:
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
