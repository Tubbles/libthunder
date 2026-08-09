package mpq

// PKWARE Data Compression Library "explode" decompressor.
//
// This is the decompressor for MPQ sectors that carry the "imploded"
// compression flag (compression mask bit 0x08). The bitstream format was
// documented by Ben Rudiak-Gould in comp.compression (13 Aug 2001) and is
// implemented independently by zlib's contrib/blast (Mark Adler, zlib
// license) and by StormLib's src/pklib/explode.c (Ladislav Zezula, MIT).
// Both were read to understand the format; this is an original Odin
// implementation, not a translation of either. The Huffman code-length
// tables below are format constants, not algorithm code: they were
// extracted verbatim from zlib's blast.c and cross-checked byte-for-byte
// against StormLib's independently authored equivalent tables (ChBitsAsc
// and DistBits) before being transcribed here.
//
// Format summary:
//   - Byte 0 of the stream selects literal encoding: 0 means literals are
//     raw uncoded bytes, 1 means literals are Huffman coded.
//   - Byte 1 gives the dictionary size as log2(window size) - 6, valid
//     values 4..6 (1KiB, 2KiB, 4KiB windows). It also sets the number of
//     raw extra bits appended to a distance code (except when the copy
//     length is exactly 2, which always uses 2 extra bits).
//   - The remaining bytes are an LSB-first bitstream of literals and
//     length/distance copy pairs, each preceded by a 1-bit tag (0 =
//     literal, 1 = length/distance pair).
//   - A decoded copy length of 519 is not a real copy: it is the
//     end-of-stream marker.
//   - The maximum representable distance is 4096, so a single fixed
//     4096-byte circular window covers every valid dictionary size.

PKWARE_MAX_CODE_LENGTH :: 13
PKWARE_WINDOW_SIZE :: 4096
PKWARE_END_OF_STREAM_LENGTH :: 519
PKWARE_MAX_HUFFMAN_SYMBOLS :: 256

// Compact canonical code-length table for the literal Huffman code (256
// symbols, one per possible literal byte value). Each entry packs a
// repeat count (high nibble, plus one) and a code length in bits (low
// nibble); expanding it yields 256 code lengths, one per literal byte in
// ascending order.
@(private)
PKWARE_LITERAL_CODE_LENGTHS := [?]u8{
	11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8,
	9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5,
	7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11, 9, 12,
	8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
	44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45,
	44, 173,
}

// Compact canonical code-length table for the length Huffman code (16
// symbols: length codes 0..15).
@(private)
PKWARE_LENGTH_CODE_LENGTHS := [?]u8{2, 35, 36, 53, 38, 23}

// Compact canonical code-length table for the distance Huffman code (64
// symbols: distance codes 0..63).
@(private)
PKWARE_DISTANCE_CODE_LENGTHS := [?]u8{2, 20, 53, 230, 247, 151, 248}

// Base copy length and extra raw bit count for each of the 16 length
// symbols. The decoded copy length is PKWARE_LENGTH_BASES[symbol] plus
// the value of PKWARE_LENGTH_EXTRA_BITS[symbol] raw bits read from the
// stream.
@(private)
PKWARE_LENGTH_BASES := [16]int{3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264}

@(private)
PKWARE_LENGTH_EXTRA_BITS := [16]int{0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8}

// Canonical Huffman decode table. length_counts[length] is the number of
// symbols with that code length; symbols holds the symbol values in
// canonical order (ascending code length, then ascending symbol index
// within a length). Sized for the largest of the three tables (the
// literal table, 256 symbols); the length and distance tables use only a
// leading portion of it.
@(private)
Pkware_Huffman_Table :: struct {
	length_counts: [PKWARE_MAX_CODE_LENGTH + 1]u16,
	symbols:       [PKWARE_MAX_HUFFMAN_SYMBOLS]u16,
}

// Builds a canonical Huffman decode table from a compact code-length
// table. Also returns the canonical "remaining code space" value: zero
// for a complete code, negative if the code lengths are over-subscribed
// (invalid), positive if incomplete. The three tables built into this
// file are fixed format constants (never read from untrusted input), so
// callers within this file do not need to check it; it exists so tests
// can confirm the transcribed tables are self-consistent.
@(private)
pkware_build_huffman_table :: proc(compact_code_lengths: []u8) -> (table: Pkware_Huffman_Table, remaining_code_space: int) {
	expanded_code_lengths: [PKWARE_MAX_HUFFMAN_SYMBOLS]u8
	symbol_count := 0
	for compact_entry in compact_code_lengths {
		repeat_count := int(compact_entry >> 4) + 1
		code_length := compact_entry & 0x0f
		for _ in 0 ..< repeat_count {
			expanded_code_lengths[symbol_count] = code_length
			symbol_count += 1
		}
	}

	for code_length in expanded_code_lengths[:symbol_count] {
		table.length_counts[code_length] += 1
	}

	remaining_code_space = 1
	for code_length in 1 ..= PKWARE_MAX_CODE_LENGTH {
		remaining_code_space <<= 1
		remaining_code_space -= int(table.length_counts[code_length])
		if remaining_code_space < 0 {
			break
		}
	}

	offsets: [PKWARE_MAX_CODE_LENGTH + 1]u16
	for code_length in 1 ..< PKWARE_MAX_CODE_LENGTH {
		offsets[code_length + 1] = offsets[code_length] + table.length_counts[code_length]
	}

	for symbol_index in 0 ..< symbol_count {
		code_length := expanded_code_lengths[symbol_index]
		if code_length == 0 {
			continue
		}
		table.symbols[offsets[code_length]] = u16(symbol_index)
		offsets[code_length] += 1
	}

	return table, remaining_code_space
}

// Reads bits from a byte slice, least-significant bit first within each
// byte, buffering across byte boundaries.
@(private)
Pkware_Bit_Reader :: struct {
	data:          []u8,
	byte_position: int,
	bit_buffer:    u32,
	bit_count:     int,
}

@(private)
pkware_read_bits :: proc(reader: ^Pkware_Bit_Reader, requested_bit_count: int) -> (value: int, ok: bool) {
	for reader.bit_count < requested_bit_count {
		if reader.byte_position >= len(reader.data) {
			return 0, false
		}
		reader.bit_buffer |= u32(reader.data[reader.byte_position]) << u32(reader.bit_count)
		reader.byte_position += 1
		reader.bit_count += 8
	}

	mask := (u32(1) << u32(requested_bit_count)) - 1
	value = int(reader.bit_buffer & mask)
	reader.bit_buffer >>= u32(requested_bit_count)
	reader.bit_count -= requested_bit_count
	return value, true
}

// Decodes one symbol from the bitstream using a canonical Huffman table.
// PKWARE's canonical codes are bit-inverted relative to the usual
// ascending-code convention (the shortest code is all ones, not all
// zeros), so each raw bit is inverted before being folded into the
// running code value.
@(private)
pkware_decode_huffman_symbol :: proc(reader: ^Pkware_Bit_Reader, table: ^Pkware_Huffman_Table) -> (symbol: int, ok: bool) {
	code := 0
	first := 0
	index := 0
	for code_length in 1 ..= PKWARE_MAX_CODE_LENGTH {
		bit, read_ok := pkware_read_bits(reader, 1)
		if !read_ok {
			return 0, false
		}
		code = (code << 1) | (1 - bit)

		count := int(table.length_counts[code_length])
		if code - first < count {
			return int(table.symbols[index + (code - first)]), true
		}
		index += count
		first = (first + count) << 1
	}
	return 0, false
}

// pkware_explode decompresses a PKWARE DCL "implode" stream (the format
// used by MPQ sectors with the "imploded" compression flag).
//
// expected_size is the maximum plausible output size, normally the exact
// sector size; the returned data may be shorter, but if the stream would
// produce more than expected_size bytes, decompression stops and
// .Output_Size_Mismatch is returned. Malformed or truncated input yields
// .Corrupt_Data. On success the returned slice is allocated with
// allocator and owned by the caller.
pkware_explode :: proc(compressed_data: []u8, expected_size: int, allocator := context.allocator) -> (decompressed_data: []u8, error: Decompress_Error) {
	reader := Pkware_Bit_Reader{data = compressed_data}

	literal_mode_value, literal_mode_ok := pkware_read_bits(&reader, 8)
	if !literal_mode_ok || literal_mode_value > 1 {
		return nil, .Corrupt_Data
	}
	literals_are_huffman_coded := literal_mode_value == 1

	dictionary_size_bits, dictionary_size_ok := pkware_read_bits(&reader, 8)
	if !dictionary_size_ok || dictionary_size_bits < 4 || dictionary_size_bits > 6 {
		return nil, .Corrupt_Data
	}

	literal_table, _ := pkware_build_huffman_table(PKWARE_LITERAL_CODE_LENGTHS[:])
	length_table, _ := pkware_build_huffman_table(PKWARE_LENGTH_CODE_LENGTHS[:])
	distance_table, _ := pkware_build_huffman_table(PKWARE_DISTANCE_CODE_LENGTHS[:])

	window: [PKWARE_WINDOW_SIZE]u8
	working_output := make([]u8, expected_size, allocator)
	defer delete(working_output, allocator)
	output_length := 0

	for {
		is_length_distance_pair, tag_ok := pkware_read_bits(&reader, 1)
		if !tag_ok {
			return nil, .Corrupt_Data
		}

		if is_length_distance_pair == 0 {
			literal_byte: int
			literal_ok: bool
			if literals_are_huffman_coded {
				literal_byte, literal_ok = pkware_decode_huffman_symbol(&reader, &literal_table)
			} else {
				literal_byte, literal_ok = pkware_read_bits(&reader, 8)
			}
			if !literal_ok {
				return nil, .Corrupt_Data
			}

			if output_length >= expected_size {
				return nil, .Output_Size_Mismatch
			}
			window[output_length % PKWARE_WINDOW_SIZE] = u8(literal_byte)
			working_output[output_length] = u8(literal_byte)
			output_length += 1
			continue
		}

		length_symbol, length_symbol_ok := pkware_decode_huffman_symbol(&reader, &length_table)
		if !length_symbol_ok {
			return nil, .Corrupt_Data
		}
		extra_length_value, extra_length_ok := pkware_read_bits(&reader, PKWARE_LENGTH_EXTRA_BITS[length_symbol])
		if !extra_length_ok {
			return nil, .Corrupt_Data
		}
		copy_length := PKWARE_LENGTH_BASES[length_symbol] + extra_length_value

		if copy_length == PKWARE_END_OF_STREAM_LENGTH {
			break
		}

		distance_extra_bit_count := dictionary_size_bits
		if copy_length == 2 {
			distance_extra_bit_count = 2
		}

		distance_symbol, distance_symbol_ok := pkware_decode_huffman_symbol(&reader, &distance_table)
		if !distance_symbol_ok {
			return nil, .Corrupt_Data
		}
		distance_extra_value, distance_extra_ok := pkware_read_bits(&reader, distance_extra_bit_count)
		if !distance_extra_ok {
			return nil, .Corrupt_Data
		}
		copy_distance := (distance_symbol << uint(distance_extra_bit_count)) + distance_extra_value + 1

		if copy_distance > output_length {
			return nil, .Corrupt_Data
		}

		for _ in 0 ..< copy_length {
			if output_length >= expected_size {
				return nil, .Output_Size_Mismatch
			}
			source_byte := window[(output_length - copy_distance) % PKWARE_WINDOW_SIZE]
			window[output_length % PKWARE_WINDOW_SIZE] = source_byte
			working_output[output_length] = source_byte
			output_length += 1
		}
	}

	result := make([]u8, output_length, allocator)
	copy(result, working_output[:output_length])
	return result, .None
}
