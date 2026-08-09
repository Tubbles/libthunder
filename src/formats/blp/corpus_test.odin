package blp

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

// Reference pixel values below were derived with an independent
// Python decode of the same corpus files (WI-0008 log, 2026-08-09).

@(test)
corpus_palettized_selection_circle_decodes :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "ReplaceableTextures\\Selection\\SelectionCircleLarge.blp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)

	texture_info, info_error := info(data)
	testing.expect_value(t, info_error, Error.None)
	testing.expect_value(t, texture_info.compression, Compression.Palettized)
	testing.expect_value(t, texture_info.width, 128)
	testing.expect_value(t, texture_info.height, 128)
	testing.expect_value(t, texture_info.alpha_bits, 8)
	testing.expect_value(t, texture_info.mip_count, 8)

	pixels, width, _, decode_error := decode_mip(data, 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)

	// (57,3) is white with alpha 230; (3,64) alpha 228; (0,0) fully
	// transparent white.
	check :: proc(t: ^testing.T, pixels: []u8, width: int, x: int, y: int, expected: [4]u8) {
		base := (y * width + x) * 4
		testing.expect_value(t, pixels[base + 0], expected[0])
		testing.expect_value(t, pixels[base + 1], expected[1])
		testing.expect_value(t, pixels[base + 2], expected[2])
		testing.expect_value(t, pixels[base + 3], expected[3])
	}
	check(t, pixels, width, 57, 3, {255, 255, 255, 230})
	check(t, pixels, width, 3, 64, {255, 255, 255, 228})
	check(t, pixels, width, 0, 0, {255, 255, 255, 0})

	// Every mip level must decode.
	for mip_index in 0 ..< texture_info.mip_count {
		mip_pixels, mip_width, mip_height, mip_error := decode_mip(data, mip_index)
		defer delete(mip_pixels)
		testing.expect_value(t, mip_error, Error.None)
		testing.expect_value(t, len(mip_pixels), mip_width * mip_height * 4)
	}
}

@(test)
corpus_palettized_no_alpha_decodes :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "UI\\Buttons\\HeroLevel\\HeroLevel-Border.blp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)

	texture_info, info_error := info(data)
	testing.expect_value(t, info_error, Error.None)
	testing.expect_value(t, texture_info.alpha_bits, 0)

	pixels, _, _, decode_error := decode_mip(data, 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	for pixel_index in 0 ..< texture_info.width * texture_info.height {
		if pixels[pixel_index * 4 + 3] != 255 {
			testing.fail_now(t, "expected fully opaque texture")
		}
	}
}
