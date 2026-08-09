package mpq

// Sector decompression dispatch. A COMPRESSED sector's first stored
// byte is a bitmask of methods, applied at decompression time in the
// order entropy coder first (Huffman/zlib/PKWARE), ADPCM last. WC3-era
// archives use zlib, PKWARE, and Huffman+ADPCM for audio; bzip2 and
// sparse are later-era methods, reported as unsupported until a real
// 1.29 corpus file proves the need.

import "base:runtime"
import "core:bytes"
import zlib "core:compress/zlib"

Decompress_Error :: enum {
	None,
	Corrupt_Data,
	Output_Size_Mismatch,
	Unsupported,
}

COMPRESSION_HUFFMAN :: u8(0x01)
COMPRESSION_ZLIB :: u8(0x02)
COMPRESSION_PKWARE :: u8(0x08)
COMPRESSION_BZIP2 :: u8(0x10)
COMPRESSION_SPARSE :: u8(0x20)
COMPRESSION_ADPCM_MONO :: u8(0x40)
COMPRESSION_ADPCM_STEREO :: u8(0x80)

decompress_sector :: proc(method_mask: u8, stored: []u8, expected_size: int, allocator: runtime.Allocator) -> (data: []u8, error: Error) {
	if method_mask & (COMPRESSION_BZIP2 | COMPRESSION_SPARSE) != 0 {
		return nil, .Unsupported_Compression
	}
	if method_mask == 0 {
		return nil, .Decompression_Failed
	}

	current := stored
	current_is_owned := false
	advance :: proc(current: ^[]u8, current_is_owned: ^bool, next: []u8, allocator: runtime.Allocator) {
		if current_is_owned^ {
			delete(current^, allocator)
		}
		current^ = next
		current_is_owned^ = true
	}
	discard_current := true
	defer if discard_current && current_is_owned {
		delete(current, allocator)
	}

	translate :: proc(codec_error: Decompress_Error) -> Error {
		return .Unsupported_Compression if codec_error == .Unsupported else .Decompression_Failed
	}

	// Entropy stages; expected_size is an upper bound for these when an
	// ADPCM stage still follows (ADPCM input is smaller than its output).
	if method_mask & COMPRESSION_HUFFMAN != 0 {
		next, huffman_error := huffman_decompress(current, expected_size, allocator)
		if huffman_error != .None {
			return nil, translate(huffman_error)
		}
		advance(&current, &current_is_owned, next, allocator)
	}
	if method_mask & COMPRESSION_ZLIB != 0 {
		next, zlib_error := zlib_decompress(current, expected_size, allocator)
		if zlib_error != .None {
			return nil, translate(zlib_error)
		}
		advance(&current, &current_is_owned, next, allocator)
	}
	if method_mask & COMPRESSION_PKWARE != 0 {
		next, pkware_error := pkware_explode(current, expected_size, allocator)
		if pkware_error != .None {
			return nil, translate(pkware_error)
		}
		advance(&current, &current_is_owned, next, allocator)
	}
	if method_mask & (COMPRESSION_ADPCM_MONO | COMPRESSION_ADPCM_STEREO) != 0 {
		channel_count := 2 if method_mask & COMPRESSION_ADPCM_STEREO != 0 else 1
		next, adpcm_error := adpcm_decompress(current, expected_size, channel_count, allocator)
		if adpcm_error != .None {
			return nil, translate(adpcm_error)
		}
		advance(&current, &current_is_owned, next, allocator)
	}

	if !current_is_owned {
		// No stage ran; only unsupported bits were set (handled above),
		// so this is unreachable, but stay defensive about aliasing.
		return nil, .Decompression_Failed
	}
	if len(current) != expected_size {
		return nil, .Size_Mismatch
	}
	discard_current = false
	return current, .None
}

@(private)
zlib_decompress :: proc(compressed_data: []u8, expected_size: int, allocator := context.allocator) -> (data: []u8, error: Decompress_Error) {
	context.allocator = allocator
	buffer: bytes.Buffer
	inflate_error := zlib.inflate_from_byte_array(compressed_data, &buffer, false, expected_size)
	if inflate_error != nil {
		bytes.buffer_destroy(&buffer)
		return nil, .Corrupt_Data
	}
	result := bytes.buffer_to_bytes(&buffer)
	if len(result) > expected_size {
		bytes.buffer_destroy(&buffer)
		return nil, .Output_Size_Mismatch
	}
	return result, .None
}
