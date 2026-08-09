package mpq

import "core:testing"

// The two table keys are widely published reference constants of the
// format (every MPQ implementation derives the same values).
@(test)
hash_string_matches_reference_constants :: proc(t: ^testing.T) {
	testing.expect_value(t, hash_string("(hash table)", .File_Key), u32(0xC3AF_3770))
	testing.expect_value(t, hash_string("(block table)", .File_Key), u32(0xEC83_B3A3))
}

@(test)
hash_string_is_case_and_slash_insensitive :: proc(t: ^testing.T) {
	reference := hash_string("Scripts\\Common.J", .Table_Offset)
	testing.expect_value(t, hash_string("scripts/common.j", .Table_Offset), reference)
	testing.expect_value(t, hash_string("SCRIPTS\\COMMON.J", .Table_Offset), reference)
}

@(test)
encrypt_then_decrypt_round_trips :: proc(t: ^testing.T) {
	original := [16]u8{1, 2, 3, 4, 50, 60, 70, 80, 255, 254, 253, 252, 0, 0, 0, 1}
	working := original
	encrypt_block(working[:], 0xDEAD_BEEF)
	testing.expect(t, working != original, "encryption changed nothing")
	decrypt_block(working[:], 0xDEAD_BEEF)
	testing.expect_value(t, working, original)
}

@(test)
decrypt_leaves_short_tail_untouched :: proc(t: ^testing.T) {
	data := [6]u8{10, 20, 30, 40, 111, 222}
	decrypt_block(data[:], 12345)
	testing.expect_value(t, data[4], u8(111))
	testing.expect_value(t, data[5], u8(222))
}
