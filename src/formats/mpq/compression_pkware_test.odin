package mpq

import "core:testing"

// Reference vector from zlib's contrib/blast (blast.c, "Change history"
// header comment): corrected version of the example given by Ben
// Rudiak-Gould in comp.compression on 13 Aug 2001. Decompresses to the
// ASCII string "AIAIAIAIAIAIA" (13 bytes, uncoded literal mode).
@(private = "file")
PKWARE_REFERENCE_VECTOR := [?]u8{0x00, 0x04, 0x82, 0x24, 0x25, 0x8f, 0x80, 0x7f}

@(test)
explode_decodes_reference_vector :: proc(t: ^testing.T) {
	decompressed_data, error := pkware_explode(PKWARE_REFERENCE_VECTOR[:], 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, string(decompressed_data), "AIAIAIAIAIAIA")
}

@(test)
explode_rejects_truncated_input :: proc(t: ^testing.T) {
	truncated := PKWARE_REFERENCE_VECTOR[:len(PKWARE_REFERENCE_VECTOR) - 2]
	decompressed_data, error := pkware_explode(truncated, 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, decompressed_data == nil)
}

@(test)
explode_rejects_every_truncation_of_reference_vector :: proc(t: ^testing.T) {
	// The reference vector is packed tight: dropping any suffix of it
	// removes bits the decoder needs before it can reach the
	// end-of-stream marker, so every truncation must fail closed.
	for bytes_dropped in 1 ..= len(PKWARE_REFERENCE_VECTOR) - 1 {
		truncated := PKWARE_REFERENCE_VECTOR[:len(PKWARE_REFERENCE_VECTOR) - bytes_dropped]
		decompressed_data, error := pkware_explode(truncated, 13)
		defer delete(decompressed_data)

		testing.expectf(t, error == .Corrupt_Data, "dropping %d trailing byte(s) should yield Corrupt_Data, got %v", bytes_dropped, error)
	}
}

@(test)
explode_rejects_output_larger_than_expected_size :: proc(t: ^testing.T) {
	decompressed_data, error := pkware_explode(PKWARE_REFERENCE_VECTOR[:], 5)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Output_Size_Mismatch)
	testing.expect(t, decompressed_data == nil)
}

@(test)
explode_rejects_empty_input :: proc(t: ^testing.T) {
	decompressed_data, error := pkware_explode(nil, 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, decompressed_data == nil)
}

@(test)
explode_rejects_single_byte_input :: proc(t: ^testing.T) {
	one_byte := [1]u8{0x00}
	decompressed_data, error := pkware_explode(one_byte[:], 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, decompressed_data == nil)
}

@(test)
explode_rejects_invalid_literal_mode_byte :: proc(t: ^testing.T) {
	invalid_vector := [?]u8{0x02, 0x04, 0x82, 0x24, 0x25, 0x8f, 0x80, 0x7f}
	decompressed_data, error := pkware_explode(invalid_vector[:], 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
}

@(test)
explode_rejects_invalid_dictionary_size_byte :: proc(t: ^testing.T) {
	invalid_vector := [?]u8{0x00, 0x03, 0x82, 0x24, 0x25, 0x8f, 0x80, 0x7f}
	decompressed_data, error := pkware_explode(invalid_vector[:], 13)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
}

// Cross-check of the transcribed format tables: each of the three fixed
// Huffman code-length tables built into compression_pkware.odin must
// describe a complete canonical code (remaining_code_space == 0). This
// would catch a transcription error in the tables even though none of
// the other tests exercise the Huffman-coded-literal path or every
// length/distance symbol.
@(test)
pkware_huffman_tables_are_complete_canonical_codes :: proc(t: ^testing.T) {
	_, literal_remaining_code_space := pkware_build_huffman_table(PKWARE_LITERAL_CODE_LENGTHS[:])
	_, length_remaining_code_space := pkware_build_huffman_table(PKWARE_LENGTH_CODE_LENGTHS[:])
	_, distance_remaining_code_space := pkware_build_huffman_table(PKWARE_DISTANCE_CODE_LENGTHS[:])

	testing.expect_value(t, literal_remaining_code_space, 0)
	testing.expect_value(t, length_remaining_code_space, 0)
	testing.expect_value(t, distance_remaining_code_space, 0)
}

// Hand-built minimal stream: uncoded literal mode, 4KiB dictionary,
// exactly one literal byte, and nothing else. Exercises the plain
// literal path and Output_Size_Mismatch triggered on the very first
// byte, independent of the reference vector's length/distance pair.
@(test)
explode_single_literal_hits_output_size_mismatch_immediately :: proc(t: ^testing.T) {
	// literal_mode=0, dict=4, then a literal tag bit (0) followed by the
	// 8 bits of the literal byte 0x41 ('A'), LSB-first. The tag bit and
	// the low 7 bits of 0x41 pack into the first stream byte (0x82); the
	// top bit of 0x41 spills into the second stream byte's bit 0, with
	// the rest of that byte unused padding.
	vector := [?]u8{0x00, 0x04, 0x82, 0x00}
	decompressed_data, error := pkware_explode(vector[:], 0)
	defer delete(decompressed_data)

	testing.expect_value(t, error, Decompress_Error.Output_Size_Mismatch)
	testing.expect(t, decompressed_data == nil)
}
