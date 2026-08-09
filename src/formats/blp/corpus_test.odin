package blp

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
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
corpus_jpeg_blps_decode :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	// Channel mapping and accuracy of this path were cross-validated
	// against an independent Pillow decode of the same files: max
	// difference of 1 per channel (WI-0008 log, 2026-08-09).
	Sample :: struct {
		path:                string,
		expected_alpha_bits: int,
	}
	samples := [?]Sample {
		{"UI\\Glues\\Loading\\Multiplayer\\Loading-BotLeft.blp", 0},
		{"Abilities\\Spells\\Human\\Brilliance\\TjShockwave2.blp", 8},
	}
	for sample in samples {
		data, read_error := mpq.read_file(archive, sample.path)
		defer delete(data)
		testing.expect_value(t, read_error, mpq.Error.None)

		texture_info, info_error := info(data)
		testing.expect_value(t, info_error, Error.None)
		testing.expect_value(t, texture_info.compression, Compression.Jpeg)
		testing.expect_value(t, texture_info.alpha_bits, sample.expected_alpha_bits)

		for mip_index in 0 ..< texture_info.mip_count {
			pixels, mip_width, mip_height, mip_error := decode_mip(data, mip_index)
			defer delete(pixels)
			testing.expect_value(t, mip_error, Error.None)
			expected_width, expected_height := mip_dimensions(texture_info, mip_index)
			testing.expect_value(t, mip_width, expected_width)
			testing.expect_value(t, mip_height, expected_height)
			testing.expect_value(t, len(pixels), mip_width * mip_height * 4)
		}
	}
}

// Decodes mip 0 of every BLP in War3.mpq and War3x.mpq. GB-scale work,
// so gated like the MPQ sweep.
@(test)
corpus_all_blps_decode :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	archive_names := [?]string{"War3.mpq", "War3x.mpq"}
	for archive_name in archive_names {
		archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", archive_name})
		defer delete(archive_path)
		if !os.exists(archive_path) {
			continue
		}

		archive, open_error := mpq.open(archive_path)
		testing.expect_value(t, open_error, mpq.Error.None)
		defer mpq.close(archive)

		listfile, listfile_error := mpq.read_file(archive, "(listfile)")
		defer delete(listfile)
		testing.expect_value(t, listfile_error, mpq.Error.None)

		decoded_count := 0
		failed_count := 0
		listfile_text := string(listfile)
		for line in strings.split_lines_iterator(&listfile_text) {
			file_name := strings.trim_space(line)
			lowered := strings.to_lower(file_name)
			is_blp := strings.has_suffix(lowered, ".blp")
			delete(lowered)
			if !is_blp {
				continue
			}

			data, read_error := mpq.read_file(archive, file_name)
			if read_error != .None {
				failed_count += 1
				delete(data)
				continue
			}
			pixels, _, _, decode_error := decode_mip(data, 0)
			if decode_error == .None {
				decoded_count += 1
			} else {
				failed_count += 1
				if failed_count <= 20 {
					log.infof("%s: %v: %s", archive_name, decode_error, file_name)
				}
			}
			delete(pixels)
			delete(data)
		}
		log.infof("%s: decoded %d BLPs, failed %d", archive_name, decoded_count, failed_count)
		testing.expect_value(t, failed_count, 0)
		testing.expect(t, decoded_count > 0, "sweep decoded nothing")
	}
}

// This file stores a 10-entry palette with mip 0 starting 40 bytes
// after the header, the only truncated palette in the 1.29.2 corpus.
// Reference pixels from an independent Python decode (WI-0008 log,
// 2026-08-09).
@(test)
corpus_truncated_palette_blp_decodes :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "ReplaceableTextures\\WorldEditUI\\Editor-Toolbar-MapValidation.blp")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)

	texture_info, info_error := info(data)
	testing.expect_value(t, info_error, Error.None)
	testing.expect_value(t, texture_info.compression, Compression.Palettized)
	testing.expect_value(t, texture_info.width, 16)
	testing.expect_value(t, texture_info.height, 16)
	testing.expect_value(t, texture_info.mip_count, 5)

	pixels, width, _, decode_error := decode_mip(data, 0)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)

	check_pixel :: proc(t: ^testing.T, pixels: []u8, width: int, x: int, y: int, expected: [4]u8) {
		base := (y * width + x) * 4
		testing.expect_value(t, pixels[base + 0], expected[0])
		testing.expect_value(t, pixels[base + 1], expected[1])
		testing.expect_value(t, pixels[base + 2], expected[2])
		testing.expect_value(t, pixels[base + 3], expected[3])
	}
	check_pixel(t, pixels, width, 0, 0, {255, 255, 255, 0})
	check_pixel(t, pixels, width, 8, 8, {70, 70, 70, 255})
	check_pixel(t, pixels, width, 4, 4, {0, 200, 0, 0})

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
