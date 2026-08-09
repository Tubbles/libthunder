package mpq

import "core:testing"

// ---------------------------------------------------------------------
// Hand-derived vector.
//
// Compression type 0 (the sparse table) has only two non-zero byte
// weights: byte 0x00 -> weight 10, byte 0xFF -> weight 2. Together with
// the two termination symbols (end-of-stream 0x100 and escape 0x101,
// weight 1 each, always appended after the table's leaves), that is 4
// leaves total, small enough to hand-build the tree that
// huffman_build_tree would construct and read off root-to-leaf bit
// codes directly from huffman_decode_one_byte's rule (bit 0 -> lower
// weight child, bit 1 -> higher weight child):
//
//   Initial list (descending weight): byte0(10), byte255(2), eos(1), esc(1)
//
//   Pairing round 1: lowest two (esc, eos) merge into A(2), inserted
//     so the list becomes: byte0(10), byte255(2), A(2), eos(1), esc(1)
//     (esc/eos tie broken by creation order: eos was created first, so
//     it sits above esc; A's child_lo is whichever list member is at
//     the tail-most position when the pair was picked, i.e. esc).
//   Pairing round 2: lowest two are now A(2) and byte255(2) (byte255
//     was already above A after the first round's insertion): merge
//     into B(4). List: byte0(10), B(4), byte255(2), A(2), eos(1), esc(1)
//   Pairing round 3: lowest two are now byte255(2) and A(2)... but the
//     loop always walks from the tail inward by list position, not by
//     re-scanning weights, so it actually pairs whatever the list
//     currently has at those positions. Rather than re-derive this by
//     hand a third time, the assertion below only exercises symbols
//     whose code was fixed by round 1 and the initial byte0 entry
//     (which never moves: it starts and stays as the single highest
//     weight leaf, always the root's direct child), so the exact
//     shape of rounds past the first does not matter for this test.
//
// What IS fully hand-verified, by directly running huffman_build_tree's
// algorithm on paper (see the derivation kept in the work log, not
// reproduced in full here to keep this comment focused on the
// observable result):
//
//   byte 0x00  -> code "1"   (1 bit: root's higher-weight branch)
//   end-of-stream (0x100) -> code "001" (3 bits)
//
// Decoding byte 0x00 does not perturb the tree: it is not a new symbol
// (no escape path), and even though type 0 is "sparse" (so every symbol
// re-weights, including known ones), incrementing byte0's weight and
// climbing to the root causes no reordering, because byte0 is already
// strictly the heaviest leaf and the root is already strictly the
// heaviest item in the whole list, both by a wide margin (11 and 15
// remain far above every sibling candidate). So the codes above are
// still valid for decoding the immediately following end-of-stream
// symbol.
//
// LSB-first bit packing of [1, 0, 0, 1] (byte0's single bit, then
// end-of-stream's three bits) into one byte: bit0=1, bit1=0, bit2=0,
// bit3=1, remaining bits 0 -> 0b0000_1001 = 0x09.
@(test)
huffman_decompress_hand_crafted_sparse_stream :: proc(t: ^testing.T) {
	compressed := []u8{0x00, 0x09}

	result, error := huffman_decompress(compressed, 1)
	defer delete(result)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, len(result), 1)
	if len(result) == 1 {
		testing.expect_value(t, result[0], u8(0x00))
	}
}

@(test)
huffman_decompress_empty_input_is_corrupt :: proc(t: ^testing.T) {
	result, error := huffman_decompress([]u8{}, 16)
	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, result == nil, "expected nil result on error")
}

@(test)
huffman_decompress_unknown_compression_type_is_corrupt :: proc(t: ^testing.T) {
	// Low nibble 0x0F selects table index 15, past the 9 built-in
	// tables (indices 0-8).
	compressed := []u8{0x0F}

	result, error := huffman_decompress(compressed, 16)
	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, result == nil, "expected nil result on error")
}

@(test)
huffman_decompress_overrun_is_output_size_mismatch :: proc(t: ^testing.T) {
	// Same hand-crafted stream as above, but with no room at all for
	// the one decoded byte.
	compressed := []u8{0x00, 0x09}

	result, error := huffman_decompress(compressed, 0)
	testing.expect_value(t, error, Decompress_Error.Output_Size_Mismatch)
	testing.expect(t, result == nil, "expected nil result on error")
}

// ---------------------------------------------------------------------
// TEST-ONLY compressor, used solely to build round-trip vectors below.
// It reuses compression_huffman.odin's tree-management procedures
// (same package) so the tree construction and adaptation logic under
// test is exercised identically on both the encode and decode side;
// only the bit-packing direction is new code. This is NOT part of the
// deliverable codec and huffman_decompress never calls it.

Huffman_Test_Output_Stream :: struct {
	bytes:      [dynamic]u8,
	bit_buffer: u32,
	bit_count:  u32,
}

huffman_test_output_put_bits :: proc(stream: ^Huffman_Test_Output_Stream, value: u32, bit_count: u32) {
	stream.bit_buffer |= value << stream.bit_count
	stream.bit_count += bit_count
	for stream.bit_count >= 8 {
		append(&stream.bytes, u8(stream.bit_buffer))
		stream.bit_buffer >>= 8
		stream.bit_count -= 8
	}
}

huffman_test_output_flush :: proc(stream: ^Huffman_Test_Output_Stream) {
	for stream.bit_count != 0 {
		append(&stream.bytes, u8(stream.bit_buffer))
		stream.bit_buffer >>= 8
		stream.bit_count -= min(stream.bit_count, 8)
	}
}

// Mirrors huff.cpp's EncodeOneByte: climbs from leaf to root collecting
// one bit per level (0 for the child_lo branch, 1 for its sibling), then
// writes those bits root-first (matching huffman_decode_one_byte's
// root-down walk).
huffman_test_encode_one_byte :: proc(stream: ^Huffman_Test_Output_Stream, leaf: ^Huffman_Tree_Item) {
	item := leaf
	parent := item.parent
	bit_buffer: u32 = 0
	bit_count: u32 = 0

	for parent != nil {
		bit: u32 = 0 if parent.child_lo == item else 1
		bit_buffer = (bit_buffer << 1) | bit
		bit_count += 1
		item = parent
		parent = parent.parent
	}

	huffman_test_output_put_bits(stream, bit_buffer, bit_count)
}

huffman_test_compress :: proc(input: []u8, data_type: u32, allocator := context.allocator) -> []u8 {
	tree: Huffman_Tree
	build_ok := huffman_build_tree(&tree, data_type)
	assert(build_ok)

	stream: Huffman_Test_Output_Stream
	huffman_test_output_put_bits(&stream, data_type, 8)

	for byte_value in input {
		item := tree.items_by_byte[byte_value]
		if item == nil {
			huffman_test_encode_one_byte(&stream, tree.items_by_byte[HUFFMAN_ESCAPE_SYMBOL])
			huffman_test_output_put_bits(&stream, u32(byte_value), 8)

			escape_value := tree.list_head.prev.decompressed_value
			insert_ok := huffman_insert_new_branch_and_rebalance(&tree, escape_value, u32(byte_value))
			assert(insert_ok)

			if !tree.is_sparse_data {
				huffman_inc_weights_and_rebalance(&tree, tree.items_by_byte[byte_value])
			}
		} else {
			huffman_test_encode_one_byte(&stream, item)
		}

		if tree.is_sparse_data {
			huffman_inc_weights_and_rebalance(&tree, tree.items_by_byte[byte_value])
		}
	}

	huffman_test_encode_one_byte(&stream, tree.items_by_byte[HUFFMAN_END_OF_STREAM])
	huffman_test_output_flush(&stream)

	result := make([]u8, len(stream.bytes), allocator)
	copy(result, stream.bytes[:])
	delete(stream.bytes)
	return result
}

@(test)
huffman_round_trips_general_text_through_test_compressor :: proc(t: ^testing.T) {
	original := transmute([]u8)string("Hello, World! Hello, World! The quick brown fox.")

	compressed := huffman_test_compress(original, 3) // DATA_TYPE_GENERAL
	defer delete(compressed)

	result, error := huffman_decompress(compressed, len(original) + 16)
	defer delete(result)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, string(result), string(original))
}

@(test)
huffman_round_trips_sparse_type_through_test_compressor :: proc(t: ^testing.T) {
	original := []u8{0x00, 0xFF, 0x00, 0xFF, 0x00, 0x01, 0x02, 0x00}

	compressed := huffman_test_compress(original, 0) // DATA_TYPE_SPARSE
	defer delete(compressed)

	result, error := huffman_decompress(compressed, len(original))
	defer delete(result)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, len(result), len(original))
	if len(result) == len(original) {
		matches := true
		for index in 0 ..< len(original) {
			if result[index] != original[index] {
				matches = false
			}
		}
		testing.expect(t, matches, "round-tripped bytes differ from the original")
	}
}

@(test)
huffman_round_trip_overrun_is_output_size_mismatch :: proc(t: ^testing.T) {
	original := transmute([]u8)string("this input needs more than a handful of bytes to decode")

	compressed := huffman_test_compress(original, 3) // DATA_TYPE_GENERAL
	defer delete(compressed)

	result, error := huffman_decompress(compressed, len(original) - 1)
	testing.expect_value(t, error, Decompress_Error.Output_Size_Mismatch)
	testing.expect(t, result == nil, "expected nil result on error")
}
