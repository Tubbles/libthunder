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

// The same Pillow-generated 16x16 solid four-component baseline JPEG
// as jpeg_test.odin's solid_cmyk_jpeg (duplicated here because test
// files do not cross packages): raw stored component values are
// 235, 175, 105, 55 in declaration order, exact at quality 100.
@(private = "file")
solid_four_component_jpeg := [363]u8{
	0xFF, 0xD8, 0xFF, 0xEE, 0x00, 0x0E, 0x41, 0x64, 0x6F, 0x62, 0x65, 0x00, 0x64, 0x00, 0x00, 0x00,
	0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
	0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0xFF, 0xC0, 0x00, 0x14, 0x08, 0x00, 0x10, 0x00, 0x10,
	0x04, 0x43, 0x11, 0x00, 0x4D, 0x11, 0x00, 0x59, 0x11, 0x00, 0x4B, 0x11, 0x00, 0xFF, 0xC4, 0x00,
	0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xC4,
	0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00,
	0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13,
	0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15,
	0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25,
	0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46,
	0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66,
	0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86,
	0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4,
	0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2,
	0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9,
	0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5,
	0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x0E, 0x04, 0x43, 0x00, 0x4D, 0x00, 0x59, 0x00,
	0x4B, 0x00, 0x00, 0x3F, 0x00, 0xFE, 0xD6, 0x2B, 0xF5, 0xE2, 0xBE, 0x47, 0xAF, 0xE6, 0xDE, 0x8A,
	0x28, 0xA2, 0x8A, 0x28, 0xA2, 0x8A, 0x28, 0xA2, 0xBF, 0xFF, 0xD9,
}

// Wraps a standalone baseline JPEG into the BLP1 JPEG-content layout,
// splitting it where Blizzard does: everything before the SOF0 marker
// becomes the shared header, the rest the single mip's stream.
@(private = "file")
build_synthetic_jpeg_blp :: proc(jpeg_stream: []u8, width: u32, height: u32, alpha_bits: u32, allocator := context.allocator) -> [dynamic]u8 {
	split_index := 0
	for index in 0 ..< len(jpeg_stream) - 1 {
		if jpeg_stream[index] == 0xFF && jpeg_stream[index + 1] == 0xC0 {
			split_index = index
			break
		}
	}
	shared_header := jpeg_stream[:split_index]
	mip_stream := jpeg_stream[split_index:]
	mip0_offset := HEADER_SIZE + 4 + len(shared_header)

	append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
		append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
	}

	buffer := make([dynamic]u8, allocator)
	append(&buffer, 'B', 'L', 'P', '1')
	append_u32(&buffer, 0) // JPEG content
	append_u32(&buffer, alpha_bits)
	append_u32(&buffer, width)
	append_u32(&buffer, height)
	append_u32(&buffer, 4) // picture type, irrelevant to layout
	append_u32(&buffer, 1) // has mipmaps
	for mip_index in 0 ..< MAXIMUM_MIP_COUNT {
		append_u32(&buffer, u32(mip0_offset) if mip_index == 0 else 0)
	}
	for mip_index in 0 ..< MAXIMUM_MIP_COUNT {
		append_u32(&buffer, u32(len(mip_stream)) if mip_index == 0 else 0)
	}
	append_u32(&buffer, u32(len(shared_header)))
	append(&buffer, ..shared_header)
	append(&buffer, ..mip_stream)
	return buffer
}

// BLP declares its JPEG components in B, G, R, A order, so the raw
// stored values 235, 175, 105, 55 come out as RGBA 105, 175, 235, 55.
@(test)
jpeg_blp_with_alpha_decodes :: proc(t: ^testing.T) {
	data := build_synthetic_jpeg_blp(solid_four_component_jpeg[:], 16, 16, 8)
	defer delete(data)

	texture_info, info_error := info(data[:])
	testing.expect_value(t, info_error, Error.None)
	testing.expect_value(t, texture_info.compression, Compression.Jpeg)
	testing.expect_value(t, texture_info.mip_count, 1)

	pixels, width, height, decode_error := decode_mip(data[:], 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	testing.expect_value(t, width, 16)
	testing.expect_value(t, height, 16)
	for pixel_index in 0 ..< 16 * 16 {
		testing.expect_value(t, pixels[pixel_index * 4 + 0], u8(105))
		testing.expect_value(t, pixels[pixel_index * 4 + 1], u8(175))
		testing.expect_value(t, pixels[pixel_index * 4 + 2], u8(235))
		testing.expect_value(t, pixels[pixel_index * 4 + 3], u8(55))
	}
}

@(test)
jpeg_blp_without_alpha_is_opaque :: proc(t: ^testing.T) {
	data := build_synthetic_jpeg_blp(solid_four_component_jpeg[:], 16, 16, 0)
	defer delete(data)

	pixels, _, _, decode_error := decode_mip(data[:], 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	for pixel_index in 0 ..< 16 * 16 {
		testing.expect_value(t, pixels[pixel_index * 4 + 3], u8(255))
	}
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
