package blp

// BLP1 texture decoding to RGBA8. Two content flavors exist in the
// 1.29.2 corpus (surveyed in WI-0008): palettized (256-color BGRX
// palette, per-mip index plane plus an alpha plane iff alpha_bits is
// 8) and JPEG (shared SOI/DQT/DHT header plus per-mip baseline scans
// whose 4 raw components are B,G,R,A with no color transform). The
// alpha-plane rule was established empirically against the corpus:
// alpha_bits governs it, the picture_type field does not.

import "base:runtime"

Error :: enum {
	None,
	Invalid_Header,
	Unsupported_Format,
	Corrupt_Data,
}

Compression :: enum u32 {
	Jpeg       = 0,
	Palettized = 1,
}

HEADER_SIZE :: 156
PALETTE_SIZE :: 256 * 4
MAXIMUM_MIP_COUNT :: 16

Info :: struct {
	compression:  Compression,
	alpha_bits:   int,
	width:        int,
	height:       int,
	picture_type: u32,
	mip_count:    int,
}

info :: proc(data: []u8) -> (result: Info, error: Error) {
	if len(data) < HEADER_SIZE {
		return {}, .Invalid_Header
	}
	if data[0] != 'B' || data[1] != 'L' || data[2] != 'P' || data[3] != '1' {
		return {}, .Unsupported_Format
	}
	compression := read_u32(data, 4)
	if compression > 1 {
		return {}, .Unsupported_Format
	}
	result = Info {
		compression  = Compression(compression),
		alpha_bits   = int(read_u32(data, 8)),
		width        = int(read_u32(data, 12)),
		height       = int(read_u32(data, 16)),
		picture_type = read_u32(data, 20),
	}
	if result.width <= 0 || result.height <= 0 || result.width > 65536 || result.height > 65536 {
		return {}, .Invalid_Header
	}
	for mip_index in 0 ..< MAXIMUM_MIP_COUNT {
		if read_u32(data, 92 + mip_index * 4) == 0 {
			break
		}
		result.mip_count += 1
	}
	if result.mip_count == 0 {
		return {}, .Invalid_Header
	}
	return result, .None
}

mip_dimensions :: proc(texture_info: Info, mip_index: int) -> (width: int, height: int) {
	return max(1, texture_info.width >> u32(mip_index)), max(1, texture_info.height >> u32(mip_index))
}

// Decode one mip level to tightly packed RGBA8, row-major, top-left
// origin (as stored).
decode_mip :: proc(data: []u8, mip_index: int, allocator := context.allocator) -> (pixels: []u8, width: int, height: int, error: Error) {
	texture_info := info(data) or_return
	if mip_index < 0 || mip_index >= texture_info.mip_count {
		return nil, 0, 0, .Invalid_Header
	}

	mip_offset := int(read_u32(data, 28 + mip_index * 4))
	mip_size := int(read_u32(data, 92 + mip_index * 4))
	if mip_offset < 0 || mip_size <= 0 || mip_offset + mip_size > len(data) {
		return nil, 0, 0, .Corrupt_Data
	}
	mip_data := data[mip_offset:mip_offset + mip_size]
	width, height = mip_dimensions(texture_info, mip_index)

	switch texture_info.compression {
	case .Palettized:
		pixels, error = decode_palettized_mip(data, texture_info, mip_data, width, height, allocator)
	case .Jpeg:
		pixels, error = decode_jpeg_mip(data, texture_info, mip_data, width, height, allocator)
	}
	if error != .None {
		return nil, 0, 0, error
	}
	return pixels, width, height, .None
}

@(private)
decode_palettized_mip :: proc(data: []u8, texture_info: Info, mip_data: []u8, width: int, height: int, allocator: runtime.Allocator) -> (pixels: []u8, error: Error) {
	if len(data) < HEADER_SIZE + PALETTE_SIZE {
		return nil, .Corrupt_Data
	}
	palette := data[HEADER_SIZE:HEADER_SIZE + PALETTE_SIZE]

	pixel_count := width * height
	has_alpha_plane := texture_info.alpha_bits == 8
	expected_mip_size := pixel_count * 2 if has_alpha_plane else pixel_count
	if len(mip_data) < expected_mip_size {
		return nil, .Corrupt_Data
	}

	pixels = make([]u8, pixel_count * 4, allocator)
	for pixel_index in 0 ..< pixel_count {
		palette_index := int(mip_data[pixel_index])
		pixels[pixel_index * 4 + 0] = palette[palette_index * 4 + 2]
		pixels[pixel_index * 4 + 1] = palette[palette_index * 4 + 1]
		pixels[pixel_index * 4 + 2] = palette[palette_index * 4 + 0]
		pixels[pixel_index * 4 + 3] = mip_data[pixel_count + pixel_index] if has_alpha_plane else 255
	}
	return pixels, .None
}

@(private)
read_u32 :: proc(data: []u8, offset: int) -> u32 {
	return u32(data[offset]) | u32(data[offset + 1]) << 8 | u32(data[offset + 2]) << 16 | u32(data[offset + 3]) << 24
}
