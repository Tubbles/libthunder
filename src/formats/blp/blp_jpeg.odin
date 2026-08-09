package blp

// JPEG-content BLP1: a shared header (SOI + tables, u32 length at
// offset 156) is prepended to each mip's own SOF0+SOS stream. The 4
// coded components are raw B, G, R, A in declaration order with no
// color transform, which is why this uses the specialized raw-plane
// decoder instead of a stock JPEG library.

import "base:runtime"
import jpeg "thunder:formats/jpeg"

@(private)
decode_jpeg_mip :: proc(data: []u8, texture_info: Info, mip_data: []u8, width: int, height: int, allocator: runtime.Allocator) -> (pixels: []u8, error: Error) {
	if len(data) < HEADER_SIZE + 4 {
		return nil, .Corrupt_Data
	}
	shared_header_size := int(read_u32(data, HEADER_SIZE))
	shared_header_start := HEADER_SIZE + 4
	if shared_header_start + shared_header_size > len(data) {
		return nil, .Corrupt_Data
	}
	shared_header := data[shared_header_start:shared_header_start + shared_header_size]

	stream := make([]u8, len(shared_header) + len(mip_data), allocator)
	defer delete(stream, allocator)
	copy(stream, shared_header)
	copy(stream[len(shared_header):], mip_data)

	// The decoder validates its SOF against these dimensions before
	// allocating, so a stream disagreeing with the BLP header cannot
	// drive plane sizes.
	planes, jpeg_error := jpeg.decode_component_planes(stream, width, height, allocator)
	if jpeg_error != .None {
		return nil, .Corrupt_Data
	}
	defer jpeg.destroy(&planes)

	pixel_count := width * height
	pixels = make([]u8, pixel_count * 4, allocator)
	switch planes.component_count {
	case 4:
		use_alpha := texture_info.alpha_bits == 8
		for pixel_index in 0 ..< pixel_count {
			pixels[pixel_index * 4 + 0] = planes.planes[2][pixel_index]
			pixels[pixel_index * 4 + 1] = planes.planes[1][pixel_index]
			pixels[pixel_index * 4 + 2] = planes.planes[0][pixel_index]
			pixels[pixel_index * 4 + 3] = planes.planes[3][pixel_index] if use_alpha else 255
		}
	case 1:
		for pixel_index in 0 ..< pixel_count {
			gray := planes.planes[0][pixel_index]
			pixels[pixel_index * 4 + 0] = gray
			pixels[pixel_index * 4 + 1] = gray
			pixels[pixel_index * 4 + 2] = gray
			pixels[pixel_index * 4 + 3] = 255
		}
	case:
		// 3-component JPEG BLPs have not been observed in the corpus;
		// without a real example the B,G,R channel order would be a
		// guess, so reject rather than silently mis-decode.
		delete(pixels, allocator)
		return nil, .Unsupported_Format
	}
	return pixels, .None
}
