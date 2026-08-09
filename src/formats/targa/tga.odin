package targa

// Thin wrapper over core:image/tga presenting the same RGBA8 decode
// shape as the other format packages. WC3 uses plain uncompressed
// truecolor TGAs (pathing textures, minimap previews); the corpus has
// both 24-bit and 32-bit variants, bottom-left origin.

import "core:image"
import core_tga "core:image/tga"

Error :: enum {
	None,
	Corrupt_Data,
}

// Decodes to tightly packed RGBA8, row-major, top-left origin. The
// core loader normalizes orientation and channel order (RGB/RGBA) but
// leaves 24-bit images as 3-channel buffers (its alpha_add option is
// only cosmetic for TGA), so the alpha expansion happens here.
decode :: proc(data: []u8, allocator := context.allocator) -> (pixels: []u8, width: int, height: int, error: Error) {
	context.allocator = allocator
	loaded, load_error := core_tga.load_from_bytes(data)
	if load_error != nil {
		return nil, 0, 0, .Corrupt_Data
	}
	defer image.destroy(loaded)

	if loaded.depth != 8 {
		return nil, 0, 0, .Corrupt_Data
	}
	source_pixels := loaded.pixels.buf[:]
	pixel_count := loaded.width * loaded.height

	switch loaded.channels {
	case 4:
		pixels = make([]u8, len(source_pixels), allocator)
		copy(pixels, source_pixels)
	case 3:
		pixels = make([]u8, pixel_count * 4, allocator)
		for pixel_index in 0 ..< pixel_count {
			pixels[pixel_index * 4 + 0] = source_pixels[pixel_index * 3 + 0]
			pixels[pixel_index * 4 + 1] = source_pixels[pixel_index * 3 + 1]
			pixels[pixel_index * 4 + 2] = source_pixels[pixel_index * 3 + 2]
			pixels[pixel_index * 4 + 3] = 255
		}
	case:
		return nil, 0, 0, .Corrupt_Data
	}
	return pixels, loaded.width, loaded.height, .None
}
