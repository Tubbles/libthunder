package mpq

// The MPQ cipher and one-way hash, per the MoPaQ format documentation
// (bundled in StormLib's doc/ directory) and the byte-level tables on
// wowdev.wiki/MPQ. See docs/research/file-formats.md for sources.

Hash_Type :: enum u32 {
	Table_Offset = 0,
	Name_A       = 1,
	Name_B       = 2,
	File_Key     = 3,
}

@(private)
crypt_table: [0x500]u32

@(init, private)
initialize_crypt_table :: proc "contextless" () {
	seed: u32 = 0x0010_0001
	for index in 0 ..< 0x100 {
		table_index := index
		for _ in 0 ..< 5 {
			seed = (seed * 125 + 3) % 0x2A_AAAB
			value_high := (seed & 0xFFFF) << 16
			seed = (seed * 125 + 3) % 0x2A_AAAB
			value_low := seed & 0xFFFF
			crypt_table[table_index] = value_high | value_low
			table_index += 0x100
		}
	}
}

// Case-insensitive path hash; forward slashes count as backslashes.
hash_string :: proc "contextless" (name: string, hash_type: Hash_Type) -> u32 {
	seed1: u32 = 0x7FED_7FED
	seed2: u32 = 0xEEEE_EEEE
	for byte_index in 0 ..< len(name) {
		character := name[byte_index]
		if character == '/' {
			character = '\\'
		}
		if character >= 'a' && character <= 'z' {
			character -= 'a' - 'A'
		}
		seed1 = crypt_table[u32(hash_type) * 0x100 + u32(character)] ~ (seed1 + seed2)
		seed2 = u32(character) + seed1 + seed2 + (seed2 << 5) + 3
	}
	return seed1
}

// In-place decryption of little-endian u32 data. A trailing tail of
// fewer than 4 bytes is left untouched, matching engine behavior.
decrypt_block :: proc "contextless" (data: []u8, key: u32) {
	seed1 := key
	seed2: u32 = 0xEEEE_EEEE
	for index in 0 ..< len(data) / 4 {
		seed2 += crypt_table[0x400 + int(seed1 & 0xFF)]
		value := read_u32_little_endian(data[index * 4:]) ~ (seed1 + seed2)
		seed1 = ((~seed1 << 0x15) + 0x1111_1111) | (seed1 >> 0x0B)
		seed2 = value + seed2 + (seed2 << 5) + 3
		write_u32_little_endian(data[index * 4:], value)
	}
}

// Exact inverse of decrypt_block; needed by tests and the future writer.
encrypt_block :: proc "contextless" (data: []u8, key: u32) {
	seed1 := key
	seed2: u32 = 0xEEEE_EEEE
	for index in 0 ..< len(data) / 4 {
		seed2 += crypt_table[0x400 + int(seed1 & 0xFF)]
		plain_value := read_u32_little_endian(data[index * 4:])
		write_u32_little_endian(data[index * 4:], plain_value ~ (seed1 + seed2))
		seed1 = ((~seed1 << 0x15) + 0x1111_1111) | (seed1 >> 0x0B)
		seed2 = plain_value + seed2 + (seed2 << 5) + 3
	}
}

@(private)
read_u32_little_endian :: proc "contextless" (data: []u8) -> u32 {
	return u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16 | u32(data[3]) << 24
}

@(private)
write_u32_little_endian :: proc "contextless" (data: []u8, value: u32) {
	data[0] = u8(value)
	data[1] = u8(value >> 8)
	data[2] = u8(value >> 16)
	data[3] = u8(value >> 24)
}
