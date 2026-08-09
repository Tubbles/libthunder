package mpq

import "core:testing"

// ---------------------------------------------------------------------
// Hand-derived mono vector.
//
// compressed_data = {0xAA, 0x02, 0x64, 0x00, 0x00, 0x01}
//   byte 0: 0xAA  ignored
//   byte 1: 0x02  bit_shift
//   bytes 2-3: 0x0064 little-endian = 100, the initial predicted sample
//   byte 4: 0x00  first encoded sample
//   byte 5: 0x01  second encoded sample
//
// Step index starts at ADPCM_INITIAL_STEP_INDEX = 0x2C = 44, so
// step_size = ADPCM_STEP_SIZE_TABLE[44] = 494.
//
// Sample 1, encoded 0x00: no low bits set, so difference stays at the
// base value step_size >> bit_shift = 494 >> 2 = 123. Sign bit (0x40)
// clear, so predicted = 100 + 123 = 223 (0x00DF). Next step index =
// 44 + ADPCM_NEXT_STEP_TABLE[0x00 & 0x1F] = 44 + (-1) = 43, and
// step_size becomes ADPCM_STEP_SIZE_TABLE[43] = 449.
//
// Sample 2, encoded 0x01: bit 0x01 set, so difference =
// (449 >> 2) + (449 >> 0) = 112 + 449 = 561. Sign bit clear, so
// predicted = 223 + 561 = 784 (0x0310).
//
// Expected decompressed PCM (little-endian i16 x 3): 100, 223, 784 ->
// {0x64, 0x00, 0xDF, 0x00, 0x10, 0x03}.
@(test)
adpcm_decompress_hand_derived_mono_vector :: proc(t: ^testing.T) {
	compressed := []u8{0xAA, 0x02, 0x64, 0x00, 0x00, 0x01}
	expected := []u8{0x64, 0x00, 0xDF, 0x00, 0x10, 0x03}

	result, error := adpcm_decompress(compressed, len(expected), 1)
	defer delete(result)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, len(result), len(expected))
	if len(result) == len(expected) {
		matches := true
		for index in 0 ..< len(expected) {
			if result[index] != expected[index] {
				matches = false
			}
		}
		testing.expect(t, matches, "decoded PCM does not match the hand-derived vector")
	}
}

// ---------------------------------------------------------------------
// Hand-derived stereo vector, built on the same arithmetic as the mono
// vector above (channel 0's first encoded sample is byte-for-byte the
// same computation as the mono test's sample 1, since both channels'
// step index and difference-base setup are independent of which
// channel they belong to).
//
// compressed_data = {0xAA, 0x02, 0x64, 0x00, 0x2C, 0x01, 0x00}
//   byte 0: 0xAA  ignored
//   byte 1: 0x02  bit_shift
//   bytes 2-3: 0x0064 little-endian = 100, channel 0 initial sample
//   bytes 4-5: 0x012C little-endian = 300, channel 1 initial sample
//   byte 6: 0x00  encoded sample for channel 0 (channel index starts at
//                 channel_count - 1 = 1, so the first byte after the
//                 header flips to channel 0)
//
// Channel 0's step index is independently initialized to 0x2C = 44
// (same as the mono case), so encoded byte 0x00 decodes identically:
// predicted = 100 + 123 = 223 (0x00DF).
//
// Expected decompressed PCM (little-endian i16 x 3): ch0=100, ch1=300,
// ch0=223 -> {0x64, 0x00, 0x2C, 0x01, 0xDF, 0x00}.
@(test)
adpcm_decompress_hand_derived_stereo_vector :: proc(t: ^testing.T) {
	compressed := []u8{0xAA, 0x02, 0x64, 0x00, 0x2C, 0x01, 0x00}
	expected := []u8{0x64, 0x00, 0x2C, 0x01, 0xDF, 0x00}

	result, error := adpcm_decompress(compressed, len(expected), 2)
	defer delete(result)

	testing.expect_value(t, error, Decompress_Error.None)
	testing.expect_value(t, len(result), len(expected))
	if len(result) == len(expected) {
		matches := true
		for index in 0 ..< len(expected) {
			if result[index] != expected[index] {
				matches = false
			}
		}
		testing.expect(t, matches, "decoded PCM does not match the hand-derived stereo vector")
	}
}

@(test)
adpcm_decompress_empty_input_is_corrupt :: proc(t: ^testing.T) {
	result, error := adpcm_decompress([]u8{}, 16, 1)
	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, result == nil, "expected nil result on error")
}

@(test)
adpcm_decompress_truncated_header_is_corrupt :: proc(t: ^testing.T) {
	// Mono needs 4 header bytes (ignored + bit_shift + 2-byte initial
	// sample); only 3 are supplied.
	result, error := adpcm_decompress([]u8{0xAA, 0x02, 0x64}, 16, 1)
	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, result == nil, "expected nil result on error")
}

@(test)
adpcm_decompress_truncated_stereo_header_is_corrupt :: proc(t: ^testing.T) {
	// Stereo needs 6 header bytes (ignored + bit_shift + two 2-byte
	// initial samples); only 5 are supplied.
	result, error := adpcm_decompress([]u8{0xAA, 0x02, 0x64, 0x00, 0x2C}, 16, 2)
	testing.expect_value(t, error, Decompress_Error.Corrupt_Data)
	testing.expect(t, result == nil, "expected nil result on error")
}

@(test)
adpcm_decompress_invalid_channel_count_is_corrupt :: proc(t: ^testing.T) {
	compressed := []u8{0xAA, 0x02, 0x64, 0x00, 0x00, 0x01}

	result_zero, error_zero := adpcm_decompress(compressed, 16, 0)
	testing.expect_value(t, error_zero, Decompress_Error.Corrupt_Data)
	testing.expect(t, result_zero == nil, "expected nil result on error")

	result_three, error_three := adpcm_decompress(compressed, 16, 3)
	testing.expect_value(t, error_three, Decompress_Error.Corrupt_Data)
	testing.expect(t, result_three == nil, "expected nil result on error")
}

@(test)
adpcm_decompress_overrun_is_output_size_mismatch :: proc(t: ^testing.T) {
	// Same mono vector as the hand-derived test, but with room for only
	// the initial sample plus one decoded sample (4 bytes), not both
	// encoded samples (6 bytes).
	compressed := []u8{0xAA, 0x02, 0x64, 0x00, 0x00, 0x01}

	result, error := adpcm_decompress(compressed, 4, 1)
	testing.expect_value(t, error, Decompress_Error.Output_Size_Mismatch)
	testing.expect(t, result == nil, "expected nil result on error")
}
