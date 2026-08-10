package imp

// Reader for war3map.imp (and the identical war3campaign.imp), the
// manifest of files the author imported into the archive. The file has
// no magic: it opens with an int32 version, then an int32 entry count,
// then that many entries of one flags byte plus a NUL-terminated path.
// 11 of the 186 stock 1.29.2 maps carry one (WI-0010 survey), as does
// DemoCampaign.w3n; all twelve declare version 1, the only version
// that has ever existed.
//
// Layout from War3Net's ImportedFiles/ImportedFile readers (MIT,
// license verified; docs/research/file-formats.md), matched by
// wc3lib's importedfiles.hpp.
//
// The flags byte: neither reference knows its bit meanings. War3Net
// names the bits UNK1 to UNK16; wc3lib carries an attributed community
// note reading "tells if the path is complete or needs
// 'war3mapImported\' (5 or 8 = standard path, 10 or 13: custom path)".
// This reader stores the raw byte and does not model bits.
//
// Corpus-resolved, over all 360 entries in the corpus: only two values
// occur, 8 (214 entries) and 13 (146 entries), and they mean exactly
// what the community note says.
// - Every one of the 146 flag-13 entries names a member stored in the
//   archive verbatim under the recorded path, and none of them is
//   stored under a prefix.
// - Of the 214 flag-8 entries, 195 name a member stored under a
//   prefixed path and 11 are stored verbatim; those 11 are exactly the
//   entries whose recorded path already begins with "war3mapImported\"
//   (some third-party tool wrote the prefix into the path itself), so
//   a resolver must not prefix a path that already carries one.
// - The remaining 8 flag-8 entries are the campaign's, and they
//   resolve the same way against a different prefix: DemoCampaign.w3n
//   stores them under "war3campImported\", not "war3mapImported\".
// Values 5 and 10 do not occur in the corpus, so the note's claim
// about them is untested here.

import "base:runtime"
import "core:strings"

Error :: enum {
	None,
	Unsupported_Version,
	Truncated,
	Invalid_Count,
	Unterminated_String,
	Trailing_Data,
}

SUPPORTED_VERSION :: 1

// The two flags-byte values the corpus contains. Deliberately not an
// enum of bit meanings: the bits are unknown, these are observations.
FLAGS_STANDARD_PATH: u8 : 8
FLAGS_CUSTOM_PATH: u8 : 13

Imported_File :: struct {
	// Raw flags byte; see the package comment for what the two
	// corpus-observed values mean.
	flags: u8,
	// Path as recorded. For FLAGS_STANDARD_PATH entries this is
	// relative to the archive's import directory ("war3mapImported\"
	// in maps, "war3campImported\" in campaigns) unless it already
	// starts with that directory.
	path:  string,
}

Imported_Files :: struct {
	version:   i32,
	files:     []Imported_File,
	allocator: runtime.Allocator,
}

destroy :: proc(imported_files: ^Imported_Files) {
	for file in imported_files.files {
		delete(file.path, imported_files.allocator)
	}
	delete(imported_files.files, imported_files.allocator)
	imported_files^ = {}
}

@(private)
Reader :: struct {
	data:   []u8,
	offset: int,
}

@(private)
reader_remaining :: proc(reader: ^Reader) -> int {
	return len(reader.data) - reader.offset
}

@(private)
read_u32 :: proc(reader: ^Reader) -> (value: u32, ok: bool) {
	if reader_remaining(reader) < 4 {
		return 0, false
	}
	data := reader.data[reader.offset:]
	value = u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16 | u32(data[3]) << 24
	reader.offset += 4
	return value, true
}

@(private)
read_i32 :: proc(reader: ^Reader) -> (value: i32, ok: bool) {
	raw := read_u32(reader) or_return
	return i32(raw), true
}

@(private)
read_u8 :: proc(reader: ^Reader) -> (value: u8, ok: bool) {
	if reader_remaining(reader) < 1 {
		return 0, false
	}
	value = reader.data[reader.offset]
	reader.offset += 1
	return value, true
}

// Reads a NUL-terminated string and clones the content without the
// terminator. A string running to the end of the data is corrupt.
@(private)
read_string :: proc(reader: ^Reader, allocator: runtime.Allocator) -> (text: string, error: Error) {
	terminator := reader.offset
	for terminator < len(reader.data) && reader.data[terminator] != 0 {
		terminator += 1
	}
	if terminator == len(reader.data) {
		return "", .Unterminated_String
	}
	text = strings.clone(string(reader.data[reader.offset:terminator]), allocator)
	reader.offset = terminator + 1
	return text, .None
}

// Reads the entry count and validates it against the remaining bytes
// before the caller allocates. The arithmetic runs in i64 so a huge
// declared count cannot wrap a product into a passing check on a
// 32-bit int target.
@(private)
read_count :: proc(reader: ^Reader, minimum_element_size: i64) -> (count: int, error: Error) {
	raw, ok := read_u32(reader)
	if !ok {
		return 0, .Truncated
	}
	if i64(raw) * minimum_element_size > i64(reader_remaining(reader)) {
		return 0, .Invalid_Count
	}
	return int(raw), .None
}

// Parses a complete war3map.imp or war3campaign.imp file. On error the
// partially built value is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (imported_files: Imported_Files, error: Error) {
	building: Imported_Files
	building.allocator = allocator
	defer if error != .None {
		destroy(&building)
	}

	reader := Reader {
		data = data,
	}
	version, version_ok := read_i32(&reader)
	if !version_ok {
		return {}, .Truncated
	}
	if version != SUPPORTED_VERSION {
		return {}, .Unsupported_Version
	}
	building.version = version

	// The flags byte plus at minimum the path's NUL terminator.
	count := read_count(&reader, 2) or_return
	building.files = make([]Imported_File, count, allocator)
	for &file in building.files {
		flags, flags_ok := read_u8(&reader)
		if !flags_ok {
			return {}, .Truncated
		}
		file.flags = flags
		file.path = read_string(&reader, allocator) or_return
	}

	// Exact end-of-file: all twelve files in the corpus end here.
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Data
	}
	return building, .None
}
