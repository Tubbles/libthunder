package targa

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:testing"
import mpq "thunder:formats/mpq"

// Reference pixels derived with an independent Python (Pillow) decode
// of the same files (WI-0008 log, 2026-08-09).

@(test)
corpus_pathing_textures_decode :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	// 32-bit variant: uniform transparent magenta.
	data, read_error := mpq.read_file(archive, "PathTextures\\10x10Default.tga")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)
	pixels, width, height, decode_error := decode(data)
	defer delete(pixels)
	testing.expect_value(t, decode_error, Error.None)
	testing.expect_value(t, width, 10)
	testing.expect_value(t, height, 10)
	testing.expect_value(t, pixels[0], u8(255))
	testing.expect_value(t, pixels[1], u8(0))
	testing.expect_value(t, pixels[2], u8(255))
	testing.expect_value(t, pixels[3], u8(0))

	// 24-bit bottom-left-origin variant: display top-left is blue,
	// which proves orientation normalization.
	data2, read2_error := mpq.read_file(archive, "PathTextures\\10x10CityBuilding45.tga")
	defer delete(data2)
	testing.expect_value(t, read2_error, mpq.Error.None)
	pixels2, width2, _, decode2_error := decode(data2)
	defer delete(pixels2)
	testing.expect_value(t, decode2_error, Error.None)
	testing.expect_value(t, width2, 10)
	testing.expect_value(t, pixels2[0], u8(0))
	testing.expect_value(t, pixels2[1], u8(0))
	testing.expect_value(t, pixels2[2], u8(255))
	testing.expect_value(t, pixels2[3], u8(255))
	// (4,0) magenta.
	testing.expect_value(t, pixels2[4 * 4 + 0], u8(255))
	testing.expect_value(t, pixels2[4 * 4 + 1], u8(0))
	testing.expect_value(t, pixels2[4 * 4 + 2], u8(255))
}

@(test)
garbage_is_rejected :: proc(t: ^testing.T) {
	junk := [64]u8{}
	_, _, _, error := decode(junk[:])
	testing.expect_value(t, error, Error.Corrupt_Data)
}
