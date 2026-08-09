package mpq

// MPQ v1 archive reader. Warcraft III's Storm.dll always parses
// archives as format v1 and scans for the header magic at 512-byte
// alignment, tolerating junk before it (see docs/research/
// file-formats.md); this reader mirrors that behavior, which also
// covers .w3x/.w3m maps (HM3W wrapper at offset 0, archive at 0x200).

import "base:runtime"
import "core:os"

Error :: enum {
	None,
	Cannot_Open_File,
	No_Archive_Header,
	Invalid_Table,
	File_Not_Found,
	Read_Failed,
	Corrupt_Sector_Table,
	Decompression_Failed,
	Size_Mismatch,
	Unsupported_Compression,
}

HEADER_SIZE :: 32
HEADER_ALIGNMENT :: 0x200
MPQ_MAGIC := [4]u8{'M', 'P', 'Q', 0x1A}

// Guard against absurd table counts from corrupt or hostile archives.
MAXIMUM_TABLE_COUNT :: 0x10_0000

BLOCK_FLAG_IMPLODED :: u32(0x0000_0100)
BLOCK_FLAG_COMPRESSED :: u32(0x0000_0200)
BLOCK_FLAG_ENCRYPTED :: u32(0x0001_0000)
BLOCK_FLAG_ADJUSTED_KEY :: u32(0x0002_0000)
BLOCK_FLAG_SECTOR_CRC :: u32(0x0400_0000)
BLOCK_FLAG_SINGLE_UNIT :: u32(0x0100_0000)
BLOCK_FLAG_EXISTS :: u32(0x8000_0000)

HASH_ENTRY_EMPTY :: u32(0xFFFF_FFFF)
HASH_ENTRY_DELETED :: u32(0xFFFF_FFFE)

Header :: struct {
	header_size:        u32,
	archive_size:       u32,
	format_version:     u16,
	sector_size_shift:  u16,
	hash_table_offset:  u32,
	block_table_offset: u32,
	hash_table_count:   u32,
	block_table_count:  u32,
}

Hash_Entry :: struct {
	name_a:      u32,
	name_b:      u32,
	locale:      u16,
	platform:    u16,
	block_index: u32,
}

Block_Entry :: struct {
	data_offset:       u32,
	compressed_size:   u32,
	uncompressed_size: u32,
	flags:             u32,
}

Archive :: struct {
	file:           ^os.File,
	archive_offset: i64,
	header:         Header,
	sector_size:    int,
	hash_table:     []Hash_Entry,
	block_table:    []Block_Entry,
	allocator:      runtime.Allocator,
}

open :: proc(path: string, allocator := context.allocator) -> (archive: ^Archive, error: Error) {
	file, open_error := os.open(path)
	if open_error != nil {
		return nil, .Cannot_Open_File
	}
	defer if error != .None {
		os.close(file)
	}

	file_size, size_error := os.file_size(file)
	if size_error != nil {
		return nil, .Read_Failed
	}

	// Scan 512-byte-aligned offsets for the header magic, like the
	// real engine (protected maps rely on this tolerance).
	archive_offset: i64 = -1
	header_bytes: [HEADER_SIZE]u8
	for offset: i64 = 0; offset + HEADER_SIZE <= file_size; offset += HEADER_ALIGNMENT {
		read_count, read_error := os.read_at(file, header_bytes[:], offset)
		if read_error != nil || read_count != HEADER_SIZE {
			return nil, .Read_Failed
		}
		if header_bytes[0] == MPQ_MAGIC[0] &&
		   header_bytes[1] == MPQ_MAGIC[1] &&
		   header_bytes[2] == MPQ_MAGIC[2] &&
		   header_bytes[3] == MPQ_MAGIC[3] {
			archive_offset = offset
			break
		}
	}
	if archive_offset < 0 {
		return nil, .No_Archive_Header
	}

	header := Header {
		header_size        = read_u32_little_endian(header_bytes[4:]),
		archive_size       = read_u32_little_endian(header_bytes[8:]),
		format_version     = u16(read_u32_little_endian(header_bytes[12:]) & 0xFFFF),
		sector_size_shift  = u16(read_u32_little_endian(header_bytes[12:]) >> 16),
		hash_table_offset  = read_u32_little_endian(header_bytes[16:]),
		block_table_offset = read_u32_little_endian(header_bytes[20:]),
		hash_table_count   = read_u32_little_endian(header_bytes[24:]),
		block_table_count  = read_u32_little_endian(header_bytes[28:]),
	}
	// The real engine ignores format_version entirely (protected maps
	// fake it), so it is recorded but deliberately not validated.

	if header.hash_table_count > MAXIMUM_TABLE_COUNT || header.block_table_count > MAXIMUM_TABLE_COUNT {
		return nil, .Invalid_Table
	}
	// Hash table lookup masks the table size, which therefore must be
	// a power of two; zero-size tables are also useless.
	if header.hash_table_count == 0 || (header.hash_table_count & (header.hash_table_count - 1)) != 0 {
		return nil, .Invalid_Table
	}

	hash_table_raw, hash_error := read_encrypted_table(
		file,
		archive_offset + i64(header.hash_table_offset),
		int(header.hash_table_count) * 16,
		hash_string("(hash table)", .File_Key),
		allocator,
	)
	if hash_error != .None {
		return nil, hash_error
	}
	defer delete(hash_table_raw, allocator)

	block_table_raw, block_error := read_encrypted_table(
		file,
		archive_offset + i64(header.block_table_offset),
		int(header.block_table_count) * 16,
		hash_string("(block table)", .File_Key),
		allocator,
	)
	if block_error != .None {
		return nil, block_error
	}
	defer delete(block_table_raw, allocator)

	hash_table := make([]Hash_Entry, header.hash_table_count, allocator)
	for &entry, index in hash_table {
		raw := hash_table_raw[index * 16:]
		entry = Hash_Entry {
			name_a      = read_u32_little_endian(raw),
			name_b      = read_u32_little_endian(raw[4:]),
			locale      = u16(read_u32_little_endian(raw[8:]) & 0xFFFF),
			platform    = u16(read_u32_little_endian(raw[8:]) >> 16),
			block_index = read_u32_little_endian(raw[12:]),
		}
	}

	block_table := make([]Block_Entry, header.block_table_count, allocator)
	for &entry, index in block_table {
		raw := block_table_raw[index * 16:]
		entry = Block_Entry {
			data_offset       = read_u32_little_endian(raw),
			compressed_size   = read_u32_little_endian(raw[4:]),
			uncompressed_size = read_u32_little_endian(raw[8:]),
			flags             = read_u32_little_endian(raw[12:]),
		}
	}

	archive = new(Archive, allocator)
	archive^ = Archive {
		file           = file,
		archive_offset = archive_offset,
		header         = header,
		sector_size    = 512 << header.sector_size_shift,
		hash_table     = hash_table,
		block_table    = block_table,
		allocator      = allocator,
	}
	return archive, .None
}

close :: proc(archive: ^Archive) {
	if archive == nil {
		return
	}
	os.close(archive.file)
	delete(archive.hash_table, archive.allocator)
	delete(archive.block_table, archive.allocator)
	free(archive, archive.allocator)
}

find_file :: proc(archive: ^Archive, name: string) -> (block_index: u32, found: bool) {
	mask := u32(len(archive.hash_table) - 1)
	start_index := hash_string(name, .Table_Offset) & mask
	name_a := hash_string(name, .Name_A)
	name_b := hash_string(name, .Name_B)

	index := start_index
	for {
		entry := archive.hash_table[index]
		if entry.block_index == HASH_ENTRY_EMPTY {
			return 0, false
		}
		if entry.block_index != HASH_ENTRY_DELETED &&
		   entry.name_a == name_a && entry.name_b == name_b {
			if entry.block_index < u32(len(archive.block_table)) {
				return entry.block_index, true
			}
			return 0, false
		}
		index = (index + 1) & mask
		if index == start_index {
			return 0, false
		}
	}
}

read_file :: proc(archive: ^Archive, name: string, allocator := context.allocator) -> (data: []u8, error: Error) {
	block_index, found := find_file(archive, name)
	if !found {
		return nil, .File_Not_Found
	}
	block := archive.block_table[block_index]
	if block.flags & BLOCK_FLAG_EXISTS == 0 {
		return nil, .File_Not_Found
	}

	uncompressed_size := int(block.uncompressed_size)
	if uncompressed_size == 0 {
		return make([]u8, 0, allocator), .None
	}

	encryption_key: u32
	if block.flags & BLOCK_FLAG_ENCRYPTED != 0 {
		encryption_key = hash_string(base_name(name), .File_Key)
		if block.flags & BLOCK_FLAG_ADJUSTED_KEY != 0 {
			encryption_key = (encryption_key + block.data_offset) ~ block.uncompressed_size
		}
	}

	if block.flags & BLOCK_FLAG_SINGLE_UNIT != 0 {
		return read_single_unit(archive, block, encryption_key, allocator)
	}
	if block.flags & (BLOCK_FLAG_COMPRESSED | BLOCK_FLAG_IMPLODED) != 0 {
		return read_compressed_sectors(archive, block, encryption_key, allocator)
	}
	return read_raw_sectors(archive, block, encryption_key, allocator)
}

@(private)
read_single_unit :: proc(archive: ^Archive, block: Block_Entry, encryption_key: u32, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	stored := make([]u8, block.compressed_size, allocator)
	defer if error != .None {
		delete(stored, allocator)
	}
	if !read_exact(archive, i64(block.data_offset), stored) {
		return nil, .Read_Failed
	}
	if block.flags & BLOCK_FLAG_ENCRYPTED != 0 {
		decrypt_block(stored, encryption_key)
	}

	uncompressed_size := int(block.uncompressed_size)
	if block.compressed_size == block.uncompressed_size {
		return stored, .None
	}
	defer delete(stored, allocator)
	return decompress_stored_sector(block.flags, stored, uncompressed_size, allocator)
}

@(private)
read_raw_sectors :: proc(archive: ^Archive, block: Block_Entry, encryption_key: u32, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	stored := make([]u8, block.uncompressed_size, allocator)
	if !read_exact(archive, i64(block.data_offset), stored) {
		delete(stored, allocator)
		return nil, .Read_Failed
	}
	if block.flags & BLOCK_FLAG_ENCRYPTED != 0 {
		sector_index: u32 = 0
		for start := 0; start < len(stored); start += archive.sector_size {
			end := min(start + archive.sector_size, len(stored))
			decrypt_block(stored[start:end], encryption_key + sector_index)
			sector_index += 1
		}
	}
	return stored, .None
}

@(private)
read_compressed_sectors :: proc(archive: ^Archive, block: Block_Entry, encryption_key: u32, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	uncompressed_size := int(block.uncompressed_size)
	sector_size := archive.sector_size
	sector_count := (uncompressed_size + sector_size - 1) / sector_size
	offset_count := sector_count + 1
	if block.flags & BLOCK_FLAG_SECTOR_CRC != 0 {
		// A trailing checksum sector is appended; its offset entry is
		// read but the checksum data itself is not verified here.
		offset_count += 1
	}

	offsets_raw := make([]u8, offset_count * 4, allocator)
	defer delete(offsets_raw, allocator)
	if !read_exact(archive, i64(block.data_offset), offsets_raw) {
		return nil, .Read_Failed
	}
	if block.flags & BLOCK_FLAG_ENCRYPTED != 0 {
		decrypt_block(offsets_raw, encryption_key - 1)
	}

	sector_offsets := make([]u32, offset_count, allocator)
	defer delete(sector_offsets, allocator)
	for &offset, index in sector_offsets {
		offset = read_u32_little_endian(offsets_raw[index * 4:])
	}
	for index in 0 ..< offset_count - 1 {
		if sector_offsets[index] > sector_offsets[index + 1] ||
		   sector_offsets[index + 1] > block.compressed_size {
			return nil, .Corrupt_Sector_Table
		}
	}

	result := make([]u8, uncompressed_size, allocator)
	defer if error != .None {
		delete(result, allocator)
	}
	stored_buffer := make([]u8, sector_size + 16, allocator)
	defer delete(stored_buffer, allocator)

	for sector_index in 0 ..< sector_count {
		stored_size := int(sector_offsets[sector_index + 1] - sector_offsets[sector_index])
		result_start := sector_index * sector_size
		expected_size := min(sector_size, uncompressed_size - result_start)
		if stored_size > len(stored_buffer) || stored_size == 0 {
			return nil, .Corrupt_Sector_Table
		}

		stored := stored_buffer[:stored_size]
		if !read_exact(archive, i64(block.data_offset) + i64(sector_offsets[sector_index]), stored) {
			return nil, .Read_Failed
		}
		if block.flags & BLOCK_FLAG_ENCRYPTED != 0 {
			decrypt_block(stored, encryption_key + u32(sector_index))
		}

		if stored_size < expected_size {
			decompressed, decompress_error := decompress_stored_sector(block.flags, stored, expected_size, allocator)
			if decompress_error != .None {
				return nil, decompress_error
			}
			copy(result[result_start:], decompressed)
			delete(decompressed, allocator)
		} else if stored_size == expected_size {
			copy(result[result_start:], stored)
		} else {
			return nil, .Corrupt_Sector_Table
		}
	}
	return result, .None
}

// Decompress one stored sector, honoring the block's compression
// flavor: COMPRESSED sectors carry a leading method mask byte,
// IMPLODED (pre-TFT tooling) sectors are raw PKWARE streams.
@(private)
decompress_stored_sector :: proc(block_flags: u32, stored: []u8, expected_size: int, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	if block_flags & BLOCK_FLAG_COMPRESSED != 0 {
		if len(stored) < 2 {
			return nil, .Decompression_Failed
		}
		return decompress_sector(stored[0], stored[1:], expected_size, allocator)
	}
	decompressed, pkware_error := pkware_explode(stored, expected_size, allocator)
	if pkware_error == .Unsupported {
		return nil, .Unsupported_Compression
	}
	if pkware_error != .None {
		return nil, .Decompression_Failed
	}
	if len(decompressed) != expected_size {
		delete(decompressed, allocator)
		return nil, .Size_Mismatch
	}
	return decompressed, .None
}

@(private)
read_encrypted_table :: proc(file: ^os.File, absolute_offset: i64, byte_count: int, key: u32, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	table := make([]u8, byte_count, allocator)
	read_count, read_error := os.read_at(file, table, absolute_offset)
	if read_error != nil || read_count != byte_count {
		delete(table, allocator)
		return nil, .Invalid_Table
	}
	decrypt_block(table, key)
	return table, .None
}

@(private)
read_exact :: proc(archive: ^Archive, archive_relative_offset: i64, buffer: []u8) -> bool {
	read_count, read_error := os.read_at(archive.file, buffer, archive.archive_offset + archive_relative_offset)
	return read_error == nil && read_count == len(buffer)
}

// The file key hashes only the final path component.
@(private)
base_name :: proc(name: string) -> string {
	last_separator := -1
	for index in 0 ..< len(name) {
		if name[index] == '\\' || name[index] == '/' {
			last_separator = index
		}
	}
	return name[last_separator + 1:]
}
