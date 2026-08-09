package mpq

// MPQ IMA-ADPCM audio decompression (compression mask bits 0x40 mono /
// 0x80 stereo), ported from StormLib's adpcm.cpp / adpcm.h
// (DecompressADPCM, the format used by Storm.dll for WAV sectors).
//
// Stream layout:
//
//   byte 0            ignored (ADPCM_STREAM_HEADER_SIZE bytes are
//                      consumed for the header, but only the second byte
//                      is used; the first is skipped, matching the
//                      reference reading it twice into the same
//                      variable).
//   byte 1            bit_shift: right-shift applied to each channel's
//                      step size to get the base per-nibble difference.
//   2 bytes x channels little-endian i16 initial predicted sample, one
//                      per channel, channel 0 first.
//   1 byte per sample  encoded sample / control byte, channels
//                      interleaved starting with channel 0 (see below).
//
// Each output sample is a little-endian i16 PCM value. For stereo, the
// decoded stream interleaves channel 0 and channel 1 samples exactly as
// they were read, one word per channel per "tick" (including the two
// initial samples).
//
// Per-byte decoding, after the header:
//   0x80  repeat: decrease the current channel's step index by one (not
//         below 0), then re-emit its last predicted sample unchanged. No
//         new predicted sample is computed.
//   0x81  step-up marker: increase the current channel's step index by 8
//         (clamped to 0x58/88), and do NOT advance to the next sample;
//         the channel index is un-flipped so the following byte is
//         decoded for the SAME channel this marker was read for.
//   other a real encoded sample: bits 0x01/0x02/0x04/0x08/0x10/0x20
//         accumulate a fraction of the current step size into the
//         difference (starting from step_size >> bit_shift), and bit
//         0x40 is the sign (subtract vs. add), before clamping the
//         result to the i16 range and advancing the step index via
//         ADPCM_NEXT_STEP_TABLE.
//
// Channel order: the channel index starts one behind (channel_count - 1)
// and is advanced by one, modulo channel_count, at the top of every loop
// iteration (including 0x80/0x81 bytes), so the first real byte after
// the header always applies to channel 0. A 0x81 marker advances the
// index a second time within the same iteration, cancelling the next
// iteration's advance so the byte right after 0x81 lands back on the
// channel 0x81 was read for.
//
// There is no end-of-stream marker: decoding simply continues until the
// input bytes are exhausted, which is how the reference determines the
// output length (the caller already knows the expected PCM size from the
// WAV sector's uncompressed size).

ADPCM_MAX_CHANNEL_COUNT :: 2
ADPCM_INITIAL_STEP_INDEX :: 0x2C
ADPCM_MAX_STEP_INDEX :: 88
ADPCM_STREAM_HEADER_SIZE :: 2 // Ignored byte + bit_shift byte.
ADPCM_REPEAT_MARKER :: 0x80
ADPCM_STEP_UP_MARKER :: 0x81
ADPCM_SIGN_BIT :: 0x40

ADPCM_NEXT_STEP_TABLE := [32]i32 {
	-1, 0, -1, 4, -1, 2, -1, 6,
	-1, 1, -1, 5, -1, 3, -1, 7,
	-1, 1, -1, 5, -1, 3, -1, 7,
	-1, 2, -1, 4, -1, 6, -1, 8,
}

ADPCM_STEP_SIZE_TABLE := [89]i32 {
	7, 8, 9, 10, 11, 12, 13, 14,
	16, 17, 19, 21, 23, 25, 28, 31,
	34, 37, 41, 45, 50, 55, 60, 66,
	73, 80, 88, 97, 107, 118, 130, 143,
	157, 173, 190, 209, 230, 253, 279, 307,
	337, 371, 408, 449, 494, 544, 598, 658,
	724, 796, 876, 963, 1060, 1166, 1282, 1411,
	1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024,
	3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484,
	7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794,
	32767,
}

adpcm_get_next_step_index :: proc(step_index: int, encoded_sample: u8) -> int {
	next_index := step_index + int(ADPCM_NEXT_STEP_TABLE[encoded_sample & 0x1F])
	if next_index < 0 {
		return 0
	}
	if next_index > ADPCM_MAX_STEP_INDEX {
		return ADPCM_MAX_STEP_INDEX
	}
	return next_index
}

adpcm_update_predicted_sample :: proc(predicted_sample: int, encoded_sample: u8, difference: int) -> int {
	if encoded_sample & ADPCM_SIGN_BIT != 0 {
		return max(predicted_sample - difference, -32768)
	}
	return min(predicted_sample + difference, 32767)
}

adpcm_decode_sample :: proc(predicted_sample: int, encoded_sample: u8, step_size: int, difference: int) -> int {
	difference := difference
	if encoded_sample & 0x01 != 0 {
		difference += step_size >> 0
	}
	if encoded_sample & 0x02 != 0 {
		difference += step_size >> 1
	}
	if encoded_sample & 0x04 != 0 {
		difference += step_size >> 2
	}
	if encoded_sample & 0x08 != 0 {
		difference += step_size >> 3
	}
	if encoded_sample & 0x10 != 0 {
		difference += step_size >> 4
	}
	if encoded_sample & 0x20 != 0 {
		difference += step_size >> 5
	}
	return adpcm_update_predicted_sample(predicted_sample, encoded_sample, difference)
}

adpcm_read_i16_little_endian :: proc(data: []u8) -> i16 {
	return i16(u16(data[0]) | u16(data[1]) << 8)
}

adpcm_append_i16_little_endian :: proc(output: ^[dynamic]u8, value: i16) {
	unsigned_value := u16(value)
	append(output, u8(unsigned_value))
	append(output, u8(unsigned_value >> 8))
}

adpcm_decompress :: proc(compressed_data: []u8, expected_size: int, channel_count: int, allocator := context.allocator) -> (decompressed_data: []u8, error: Decompress_Error) {
	if channel_count < 1 || channel_count > ADPCM_MAX_CHANNEL_COUNT {
		return nil, .Corrupt_Data
	}

	header_size := ADPCM_STREAM_HEADER_SIZE + channel_count * 2
	if len(compressed_data) < header_size {
		return nil, .Corrupt_Data
	}

	bit_shift := uint(compressed_data[1])
	position := ADPCM_STREAM_HEADER_SIZE

	predicted_samples: [ADPCM_MAX_CHANNEL_COUNT]i16
	step_indexes: [ADPCM_MAX_CHANNEL_COUNT]int
	for index in 0 ..< ADPCM_MAX_CHANNEL_COUNT {
		step_indexes[index] = ADPCM_INITIAL_STEP_INDEX
	}

	output := make([dynamic]u8, 0, expected_size, allocator)

	for channel_index in 0 ..< channel_count {
		initial_sample := adpcm_read_i16_little_endian(compressed_data[position:])
		position += 2
		predicted_samples[channel_index] = initial_sample

		if len(output) + 2 > expected_size {
			delete(output)
			return nil, .Output_Size_Mismatch
		}
		adpcm_append_i16_little_endian(&output, initial_sample)
	}

	channel_index := channel_count - 1

	for position < len(compressed_data) {
		encoded_sample := compressed_data[position]
		position += 1

		channel_index = (channel_index + 1) % channel_count

		switch encoded_sample {
		case ADPCM_REPEAT_MARKER:
			if step_indexes[channel_index] != 0 {
				step_indexes[channel_index] -= 1
			}

			if len(output) + 2 > expected_size {
				delete(output)
				return nil, .Output_Size_Mismatch
			}
			adpcm_append_i16_little_endian(&output, predicted_samples[channel_index])

		case ADPCM_STEP_UP_MARKER:
			step_indexes[channel_index] += 8
			if step_indexes[channel_index] > 0x58 {
				step_indexes[channel_index] = 0x58
			}
			channel_index = (channel_index + 1) % channel_count

		case:
			step_index := step_indexes[channel_index]
			step_size := int(ADPCM_STEP_SIZE_TABLE[step_index])
			difference := step_size >> bit_shift

			decoded_sample := adpcm_decode_sample(int(predicted_samples[channel_index]), encoded_sample, step_size, difference)
			predicted_samples[channel_index] = i16(decoded_sample)

			if len(output) + 2 > expected_size {
				delete(output)
				return nil, .Output_Size_Mismatch
			}
			adpcm_append_i16_little_endian(&output, predicted_samples[channel_index])

			step_indexes[channel_index] = adpcm_get_next_step_index(step_index, encoded_sample)
		}
	}

	return output[:], .None
}
