package blp

import "core:testing"

// Builds a 4x2 palettized BLP1 with two mips and a distinctive
// palette, exercising decode exactly per the empirically established
// layout (see blp.odin header comment). The palette may be truncated
// below 256 entries, as Blizzard's own files sometimes are.
@(private = "file")
build_synthetic_palettized :: proc(alpha_bits: u32, palette_entry_count := 256, allocator := context.allocator) -> [dynamic]u8 {
	width :: 4
	height :: 2
	buffer := make([dynamic]u8, allocator)

	append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
		append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
	}

	append(&buffer, 'B', 'L', 'P', '1')
	append_u32(&buffer, 1)          // palettized
	append_u32(&buffer, alpha_bits)
	append_u32(&buffer, width)
	append_u32(&buffer, height)
	append_u32(&buffer, 5)          // picture type, irrelevant to layout
	append_u32(&buffer, 1)          // has mipmaps

	mip0_pixels :: width * height
	mip1_pixels :: 2 * 1
	plane_factor := 2 if alpha_bits == 8 else 1
	mip0_offset := HEADER_SIZE + palette_entry_count * 4
	mip0_size := mip0_pixels * plane_factor
	mip1_size := mip1_pixels * plane_factor

	for mip_index in 0 ..< MAXIMUM_MIP_COUNT {
		switch mip_index {
		case 0:
			append_u32(&buffer, u32(mip0_offset))
		case 1:
			append_u32(&buffer, u32(mip0_offset + mip0_size))
		case:
			append_u32(&buffer, 0)
		}
	}
	for mip_index in 0 ..< MAXIMUM_MIP_COUNT {
		switch mip_index {
		case 0:
			append_u32(&buffer, u32(mip0_size))
		case 1:
			append_u32(&buffer, u32(mip1_size))
		case:
			append_u32(&buffer, 0)
		}
	}

	// Palette: entry N is BGRX (10+N, 20+N, 30+N, junk).
	for palette_index in 0 ..< palette_entry_count {
		append(&buffer, u8(10 + palette_index % 200), u8(20 + palette_index % 200), u8(30 + palette_index % 200), 0xEE)
	}

	// Mip 0: indices 0..7, then alpha plane 100..107 if enabled.
	for pixel_index in 0 ..< mip0_pixels {
		append(&buffer, u8(pixel_index))
	}
	if alpha_bits == 8 {
		for pixel_index in 0 ..< mip0_pixels {
			append(&buffer, u8(100 + pixel_index))
		}
	}
	// Mip 1: indices 7, 6; alpha 200, 201.
	append(&buffer, 7, 6)
	if alpha_bits == 8 {
		append(&buffer, 200, 201)
	}
	return buffer
}

@(test)
palettized_with_alpha_decodes :: proc(t: ^testing.T) {
	data := build_synthetic_palettized(8)
	defer delete(data)

	texture_info, info_error := info(data[:])
	testing.expect_value(t, info_error, Error.None)
	testing.expect_value(t, texture_info.compression, Compression.Palettized)
	testing.expect_value(t, texture_info.mip_count, 2)
	testing.expect_value(t, texture_info.width, 4)
	testing.expect_value(t, texture_info.height, 2)

	pixels, width, height, decode_error := decode_mip(data[:], 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	testing.expect_value(t, width, 4)
	testing.expect_value(t, height, 2)
	// Pixel 3 uses palette entry 3 (BGRX 13,23,33) and alpha 103.
	testing.expect_value(t, pixels[3 * 4 + 0], u8(33))
	testing.expect_value(t, pixels[3 * 4 + 1], u8(23))
	testing.expect_value(t, pixels[3 * 4 + 2], u8(13))
	testing.expect_value(t, pixels[3 * 4 + 3], u8(103))

	mip1_pixels, mip1_width, mip1_height, mip1_error := decode_mip(data[:], 1)
	defer delete(mip1_pixels)
	testing.expect_value(t, mip1_error, Error.None)
	testing.expect_value(t, mip1_width, 2)
	testing.expect_value(t, mip1_height, 1)
	testing.expect_value(t, mip1_pixels[0 * 4 + 2], u8(17)) // blue of palette 7
	testing.expect_value(t, mip1_pixels[0 * 4 + 3], u8(200))
	testing.expect_value(t, mip1_pixels[1 * 4 + 3], u8(201))
}

@(test)
palettized_without_alpha_is_opaque :: proc(t: ^testing.T) {
	data := build_synthetic_palettized(0)
	defer delete(data)

	pixels, _, _, decode_error := decode_mip(data[:], 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	for pixel_index in 0 ..< 8 {
		testing.expect_value(t, pixels[pixel_index * 4 + 3], u8(255))
	}
}

// Regression for War3.mpq's Editor-Toolbar-MapValidation.blp: the
// palette may hold fewer than 256 entries, with mip 0 starting right
// after the last stored entry. The reader must accept that and still
// reject indices that point past what is stored.
@(test)
palettized_truncated_palette_decodes :: proc(t: ^testing.T) {
	data := build_synthetic_palettized(8, palette_entry_count = 8)
	defer delete(data)

	pixels, width, height, decode_error := decode_mip(data[:], 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	testing.expect_value(t, width, 4)
	testing.expect_value(t, height, 2)
	// Pixel 3 uses palette entry 3 (BGRX 13,23,33) and alpha 103.
	testing.expect_value(t, pixels[3 * 4 + 0], u8(33))
	testing.expect_value(t, pixels[3 * 4 + 1], u8(23))
	testing.expect_value(t, pixels[3 * 4 + 2], u8(13))
	testing.expect_value(t, pixels[3 * 4 + 3], u8(103))
}

@(test)
palettized_index_beyond_truncated_palette_errors :: proc(t: ^testing.T) {
	// Mip 0 references indices up to 7, but only 4 entries are stored.
	data := build_synthetic_palettized(8, palette_entry_count = 4)
	defer delete(data)

	pixels, _, _, decode_error := decode_mip(data[:], 0)
	testing.expect_value(t, decode_error, Error.Corrupt_Data)
	testing.expect(t, pixels == nil)
}

@(test)
invalid_inputs_error_cleanly :: proc(t: ^testing.T) {
	_, short_error := info([]u8{1, 2, 3})
	testing.expect_value(t, short_error, Error.Invalid_Header)

	bad_magic := [HEADER_SIZE]u8{}
	copy(bad_magic[:], "BLP2")
	_, magic_error := info(bad_magic[:])
	testing.expect_value(t, magic_error, Error.Unsupported_Format)

	data := build_synthetic_palettized(8)
	defer delete(data)
	_, _, _, range_error := decode_mip(data[:], 5)
	testing.expect_value(t, range_error, Error.Invalid_Header)

	truncated := data[:len(data) - 4]
	_, _, _, truncation_error := decode_mip(truncated, 1)
	testing.expect_value(t, truncation_error, Error.Corrupt_Data)
}
