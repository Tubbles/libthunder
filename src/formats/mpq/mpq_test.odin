package mpq

import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:testing"

// Hand-built archives exercise the full read path hermetically (no
// Blizzard data): header scan, table decryption, hash lookup, raw,
// encrypted, and zlib-compressed file reads.

@(private = "file")
PLAIN_CONTENT :: "Hello, thunder!"

// zlib.compress(b"thunder synthetic sector payload!" * 2, 9), embedded
// so the reader can be tested without a compressor in the codebase yet.
@(private = "file")
ZLIB_PAYLOAD_PLAIN :: "thunder synthetic sector payload!thunder synthetic sector payload!"
@(private = "file")
zlib_payload_compressed := [?]u8 {
	0x78, 0xDA, 0x2B, 0xC9, 0x28, 0xCD, 0x4B, 0x49, 0x2D, 0x52, 0x28, 0xAE, 0xCC, 0x2B, 0xC9, 0x48,
	0x2D, 0xC9, 0x4C, 0x56, 0x28, 0x4E, 0x4D, 0x2E, 0xC9, 0x2F, 0x52, 0x28, 0x48, 0xAC, 0xCC, 0xC9,
	0x4F, 0x4C, 0x51, 0x2C, 0x21, 0xA4, 0x00, 0x00, 0x67, 0x4D, 0x19, 0xA1,
}

@(private = "file")
Synthetic_File :: struct {
	name:              string,
	stored:            []u8,
	uncompressed_size: u32,
	flags:             u32,
}

@(private = "file")
append_u32_little_endian :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private = "file")
build_synthetic_archive :: proc(prefix_size: int, files: []Synthetic_File, allocator := context.allocator) -> [dynamic]u8 {
	buffer := make([dynamic]u8, allocator)
	for _ in 0 ..< prefix_size {
		append(&buffer, 0)
	}
	if prefix_size >= 4 {
		copy(buffer[:4], "HM3W")
	}

	hash_table_count :: 4
	data_start := u32(HEADER_SIZE)
	data_size: u32 = 0
	for file in files {
		data_size += u32(len(file.stored))
	}
	hash_table_offset := data_start + data_size
	block_table_offset := hash_table_offset + hash_table_count * 16

	// Header.
	append(&buffer, 'M', 'P', 'Q', 0x1A)
	append_u32_little_endian(&buffer, HEADER_SIZE)
	append_u32_little_endian(&buffer, block_table_offset + u32(len(files)) * 16)
	append_u32_little_endian(&buffer, 3 << 16) // version 0, sector shift 3
	append_u32_little_endian(&buffer, hash_table_offset)
	append_u32_little_endian(&buffer, block_table_offset)
	append_u32_little_endian(&buffer, hash_table_count)
	append_u32_little_endian(&buffer, u32(len(files)))

	// File data section.
	for file in files {
		append(&buffer, ..file.stored)
	}

	// Hash table: place entries with the same probe rule the reader uses.
	hash_entries: [hash_table_count]Hash_Entry
	for &entry in hash_entries {
		entry = Hash_Entry {
			name_a      = HASH_ENTRY_EMPTY,
			name_b      = HASH_ENTRY_EMPTY,
			locale      = 0xFFFF,
			platform    = 0xFFFF,
			block_index = HASH_ENTRY_EMPTY,
		}
	}
	for file, file_index in files {
		index := hash_string(file.name, .Table_Offset) & (hash_table_count - 1)
		for hash_entries[index].block_index != HASH_ENTRY_EMPTY {
			index = (index + 1) & (hash_table_count - 1)
		}
		hash_entries[index] = Hash_Entry {
			name_a      = hash_string(file.name, .Name_A),
			name_b      = hash_string(file.name, .Name_B),
			locale      = 0,
			platform    = 0,
			block_index = u32(file_index),
		}
	}
	hash_table_bytes := make([dynamic]u8, allocator)
	defer delete(hash_table_bytes)
	for entry in hash_entries {
		append_u32_little_endian(&hash_table_bytes, entry.name_a)
		append_u32_little_endian(&hash_table_bytes, entry.name_b)
		append_u32_little_endian(&hash_table_bytes, u32(entry.locale) | u32(entry.platform) << 16)
		append_u32_little_endian(&hash_table_bytes, entry.block_index)
	}
	encrypt_block(hash_table_bytes[:], hash_string("(hash table)", .File_Key))
	append(&buffer, ..hash_table_bytes[:])

	// Block table.
	block_table_bytes := make([dynamic]u8, allocator)
	defer delete(block_table_bytes)
	data_offset := data_start
	for file in files {
		append_u32_little_endian(&block_table_bytes, data_offset)
		append_u32_little_endian(&block_table_bytes, u32(len(file.stored)))
		append_u32_little_endian(&block_table_bytes, file.uncompressed_size)
		append_u32_little_endian(&block_table_bytes, file.flags)
		data_offset += u32(len(file.stored))
	}
	encrypt_block(block_table_bytes[:], hash_string("(block table)", .File_Key))
	append(&buffer, ..block_table_bytes[:])

	return buffer
}

@(private = "file")
write_and_open :: proc(t: ^testing.T, file_name: string, prefix_size: int, files: []Synthetic_File) -> ^Archive {
	archive_bytes := build_synthetic_archive(prefix_size, files)
	defer delete(archive_bytes)

	path, _ := filepath.join({#directory, "..", "..", "..", "tmp", file_name})
	defer delete(path)
	write_error := os.write_entire_file(path, archive_bytes[:])
	if !testing.expect(t, write_error == nil, "could not write synthetic archive") {
		return nil
	}

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	return archive
}

@(private = "file")
default_files :: proc(allocator := context.allocator) -> []Synthetic_File {
	plain := transmute([]u8)string(PLAIN_CONTENT)

	secret_content := make([]u8, 16, allocator)
	for &value, index in secret_content {
		value = u8(index)
	}
	encrypt_block(secret_content, hash_string("secret.bin", .File_Key))

	packed := make([]u8, 1 + len(zlib_payload_compressed), allocator)
	packed[0] = COMPRESSION_ZLIB
	copy(packed[1:], zlib_payload_compressed[:])

	files := make([]Synthetic_File, 3, allocator)
	files[0] = Synthetic_File{"test.txt", plain, u32(len(PLAIN_CONTENT)), BLOCK_FLAG_EXISTS}
	files[1] = Synthetic_File{"secret.bin", secret_content, 16, BLOCK_FLAG_EXISTS | BLOCK_FLAG_ENCRYPTED}
	files[2] = Synthetic_File {
		"packed.bin",
		packed,
		u32(len(ZLIB_PAYLOAD_PLAIN)),
		BLOCK_FLAG_EXISTS | BLOCK_FLAG_COMPRESSED | BLOCK_FLAG_SINGLE_UNIT,
	}
	return files
}

@(private = "file")
destroy_files :: proc(files: []Synthetic_File, allocator := context.allocator) {
	delete(files[1].stored, allocator)
	delete(files[2].stored, allocator)
	delete(files, allocator)
}

@(test)
synthetic_archive_reads_plain_encrypted_and_compressed :: proc(t: ^testing.T) {
	files := default_files()
	defer destroy_files(files)
	archive := write_and_open(t, "synthetic_basic.mpq", 0, files)
	if archive == nil {
		return
	}
	defer close(archive)

	plain, plain_error := read_file(archive, "test.txt")
	defer delete(plain)
	testing.expect_value(t, plain_error, Error.None)
	testing.expect_value(t, string(plain), PLAIN_CONTENT)

	secret, secret_error := read_file(archive, "secret.bin")
	defer delete(secret)
	testing.expect_value(t, secret_error, Error.None)
	for value, index in secret {
		testing.expect_value(t, value, u8(index))
	}

	packed, packed_error := read_file(archive, "packed.bin")
	defer delete(packed)
	testing.expect_value(t, packed_error, Error.None)
	testing.expect_value(t, string(packed), ZLIB_PAYLOAD_PLAIN)

	_, missing_error := read_file(archive, "no-such-file.txt")
	testing.expect_value(t, missing_error, Error.File_Not_Found)
}

@(test)
header_is_found_behind_aligned_prefix :: proc(t: ^testing.T) {
	files := default_files()
	defer destroy_files(files)
	archive := write_and_open(t, "synthetic_prefixed.mpq", 512, files)
	if archive == nil {
		return
	}
	defer close(archive)

	testing.expect_value(t, archive.archive_offset, i64(512))
	plain, plain_error := read_file(archive, "test.txt")
	defer delete(plain)
	testing.expect_value(t, plain_error, Error.None)
	testing.expect_value(t, string(plain), PLAIN_CONTENT)
}

@(test)
open_rejects_oversized_sector_shift :: proc(t: ^testing.T) {
	files := default_files()
	defer destroy_files(files)
	archive_bytes := build_synthetic_archive(0, files)
	defer delete(archive_bytes)
	// The version/shift word sits at header offset 12; rewrite the
	// shift half (upper 16 bits) to just above the accepted cap.
	archive_bytes[12] = 0
	archive_bytes[13] = 0
	archive_bytes[14] = MAXIMUM_SECTOR_SIZE_SHIFT + 1
	archive_bytes[15] = 0

	path, _ := filepath.join({#directory, "..", "..", "..", "tmp", "synthetic_bad_shift.mpq"})
	defer delete(path)
	write_error := os.write_entire_file(path, archive_bytes[:])
	testing.expect(t, write_error == nil)

	_, open_error := open(path)
	testing.expect_value(t, open_error, Error.Invalid_Header)
}

@(test)
failed_single_unit_decompression_frees_cleanly :: proc(t: ^testing.T) {
	// Regression: this path used to register two cleanup defers that
	// both owned the stored buffer, so a failed decompression freed it
	// twice. The tracking allocator records any such repeat free.
	garbage := [?]u8{COMPRESSION_ZLIB, 0xDE, 0xAD, 0xBE, 0xEF}
	files := [?]Synthetic_File {
		{"broken.bin", garbage[:], 64, BLOCK_FLAG_EXISTS | BLOCK_FLAG_COMPRESSED | BLOCK_FLAG_SINGLE_UNIT},
	}
	archive := write_and_open(t, "synthetic_broken_single_unit.mpq", 0, files[:])
	if archive == nil {
		return
	}
	defer close(archive)

	tracking: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking, context.allocator)
	defer mem.tracking_allocator_destroy(&tracking)
	tracking.bad_free_callback = mem.tracking_allocator_bad_free_callback_add_to_array

	data, read_error := read_file(archive, "broken.bin", mem.tracking_allocator(&tracking))
	testing.expect_value(t, read_error, Error.Decompression_Failed)
	testing.expect(t, data == nil)
	testing.expect_value(t, len(tracking.bad_free_array), 0)
	testing.expect_value(t, len(tracking.allocation_map), 0)
}

@(test)
read_rejects_stored_size_beyond_file :: proc(t: ^testing.T) {
	stored := [?]u8{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'}
	files := [?]Synthetic_File {
		{"huge.bin", stored[:], 16, BLOCK_FLAG_EXISTS | BLOCK_FLAG_COMPRESSED | BLOCK_FLAG_SINGLE_UNIT},
	}
	archive_bytes := build_synthetic_archive(0, files[:])
	defer delete(archive_bytes)

	// Rewrite the block entry's stored size (second u32) to ~4 GiB,
	// far beyond the end of the archive file. The table is encrypted
	// in place, and sits after the data and the 4-entry hash table.
	block_table_offset := HEADER_SIZE + len(stored) + 4 * 16
	block_table := archive_bytes[block_table_offset:block_table_offset + 16]
	decrypt_block(block_table, hash_string("(block table)", .File_Key))
	block_table[4] = 0x00
	block_table[5] = 0x00
	block_table[6] = 0x00
	block_table[7] = 0xF0
	encrypt_block(block_table, hash_string("(block table)", .File_Key))

	path, _ := filepath.join({#directory, "..", "..", "..", "tmp", "synthetic_overrun_block.mpq"})
	defer delete(path)
	write_error := os.write_entire_file(path, archive_bytes[:])
	testing.expect(t, write_error == nil)

	archive, open_error := open(path)
	testing.expect_value(t, open_error, Error.None)
	if archive == nil {
		return
	}
	defer close(archive)

	// Must fail before allocating the claimed ~4 GiB: serve the read
	// from a small fixed arena that such an allocation would burst.
	backing := make([]u8, 64 * 1024)
	defer delete(backing)
	arena: mem.Arena
	mem.arena_init(&arena, backing)
	data, read_error := read_file(archive, "huge.bin", mem.arena_allocator(&arena))
	testing.expect_value(t, read_error, Error.Read_Failed)
	testing.expect(t, data == nil)
}

@(test)
read_rejects_uncompressed_size_over_cap :: proc(t: ^testing.T) {
	stored := [?]u8{'A', 'B', 'C', 'D'}
	files := [?]Synthetic_File {
		{"bloated.bin", stored[:], MAXIMUM_UNCOMPRESSED_FILE_SIZE + 1, BLOCK_FLAG_EXISTS | BLOCK_FLAG_COMPRESSED | BLOCK_FLAG_SINGLE_UNIT},
	}
	archive := write_and_open(t, "synthetic_bloated.mpq", 0, files[:])
	if archive == nil {
		return
	}
	defer close(archive)

	backing := make([]u8, 64 * 1024)
	defer delete(backing)
	arena: mem.Arena
	mem.arena_init(&arena, backing)
	data, read_error := read_file(archive, "bloated.bin", mem.arena_allocator(&arena))
	testing.expect_value(t, read_error, Error.File_Too_Large)
	testing.expect(t, data == nil)
}

@(test)
open_rejects_file_without_header :: proc(t: ^testing.T) {
	path, _ := filepath.join({#directory, "..", "..", "..", "tmp", "not_an_archive.bin"})
	defer delete(path)
	junk := [600]u8{}
	write_error := os.write_entire_file(path, junk[:])
	testing.expect(t, write_error == nil)

	_, open_error := open(path)
	testing.expect_value(t, open_error, Error.No_Archive_Header)
}
