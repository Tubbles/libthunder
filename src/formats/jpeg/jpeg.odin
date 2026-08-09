// A specialized baseline JPEG decoder for the streams embedded in
// Warcraft III BLP1 textures.
//
// Scope, by design: SOF0 (baseline sequential DCT) only, 8-bit sample
// precision, 1 to 4 components, every component sampled at 1x1 (BLP
// never subsamples). The decoder returns the raw, per-component
// sample planes exactly as coded, with no YCbCr or CMYK color
// transform: BLP stores B, G, R, A directly as the JPEG components,
// so applying a color transform would destroy the data.
package jpeg

import "base:runtime"
import "core:math"

Error :: enum {
	None,
	Corrupt_Stream,
	Unsupported_Feature,
}

Decoded_Planes :: struct {
	width:           int,
	height:          int,
	component_count: int,
	// planes[component][y * width + x]; only the first
	// component_count planes are non-nil. Values exactly as coded,
	// no color transform.
	planes:          [4][]u8,
	allocator:       runtime.Allocator,
}

// Decodes every component plane of the single scan in `stream`.
//
// `stream` must start with the SOI marker. Anything past the first
// (and only supported) scan is ignored, including a missing EOI.
decode_component_planes :: proc(stream: []u8, allocator := context.allocator) -> (result: Decoded_Planes, error: Error) {
	reader := Byte_Reader{data = stream}

	first_byte := read_u8(&reader) or_return
	second_byte := read_u8(&reader) or_return
	if first_byte != 0xFF || cast(Marker)second_byte != .SOI {
		return result, .Corrupt_Stream
	}

	quantization_tables: [MAX_QUANTIZATION_TABLES]Quantization_Table
	dc_huffman_tables: [MAX_HUFFMAN_TABLES]Huffman_Table
	ac_huffman_tables: [MAX_HUFFMAN_TABLES]Huffman_Table
	restart_interval := 0
	frame: Frame_Info
	have_frame := false

	for {
		marker_byte := read_u8(&reader) or_return
		if marker_byte != 0xFF {
			return result, .Corrupt_Stream
		}
		marker_byte = read_u8(&reader) or_return
		for marker_byte == 0xFF {
			// Fill bytes are allowed between the 0xFF and the marker code.
			marker_byte = read_u8(&reader) or_return
		}
		marker := cast(Marker)marker_byte

		#partial switch marker {
		case .TEM:
			// Standalone marker, no length field.
			continue
		case .DQT:
			parse_dqt(&reader, &quantization_tables) or_return
		case .DHT:
			parse_dht(&reader, &dc_huffman_tables, &ac_huffman_tables) or_return
		case .DRI:
			restart_interval = parse_dri(&reader) or_return
		case .SOF0:
			if have_frame {
				return result, .Corrupt_Stream
			}
			frame = parse_sof0(&reader) or_return
			have_frame = true
		case .SOF1, .SOF2, .SOF3, .SOF5, .SOF6, .SOF7, .SOF9, .SOF10, .SOF11, .SOF13, .SOF14, .SOF15:
			return result, .Unsupported_Feature
		case .RST0..=.RST7:
			// Restart markers only ever belong inside a scan's entropy
			// coded data, where they are consumed by the bit reader.
			return result, .Corrupt_Stream
		case .SOS:
			if !have_frame {
				return result, .Corrupt_Stream
			}
			scan_components := parse_sos(&reader, frame) or_return
			result = decode_entropy_coded_data(
				stream,
				reader.position,
				frame,
				scan_components,
				&quantization_tables,
				&dc_huffman_tables,
				&ac_huffman_tables,
				restart_interval,
				allocator,
			) or_return
			return result, .None
		case .EOI:
			return result, .Corrupt_Stream
		case:
			skip_segment(&reader) or_return
		}
	}
}

destroy :: proc(result: ^Decoded_Planes) {
	for component_index in 0..<result.component_count {
		delete(result.planes[component_index], result.allocator)
	}
	result^ = {}
}

MAX_QUANTIZATION_TABLES :: 4
MAX_HUFFMAN_TABLES :: 4
MAX_DC_CATEGORY :: 11
MAX_AC_CATEGORY :: 10
BLOCK_SIZE :: 8
COEFFICIENTS_PER_BLOCK :: 64
INVERSE_SQRT2 :: 0.70710678118654752440

Quantization_Table :: [COEFFICIENTS_PER_BLOCK]u16

// Natural (row-major, frequency-space) index for the k-th coefficient
// of a zigzag-ordered scan, per ITU T.81 Annex A, Figure A.6.
@(private = "file")
zigzag_order := [COEFFICIENTS_PER_BLOCK]u8{
	0,  1,  8, 16,  9,  2,  3, 10,
	17, 24, 32, 25, 18, 11,  4,  5,
	12, 19, 26, 33, 40, 48, 41, 34,
	27, 20, 13,  6,  7, 14, 21, 28,
	35, 42, 49, 56, 57, 50, 43, 36,
	29, 22, 15, 23, 30, 37, 44, 51,
	58, 59, 52, 45, 38, 31, 39, 46,
	53, 60, 61, 54, 47, 55, 62, 63,
}

Marker :: enum u8 {
	TEM   = 0x01,
	SOF0  = 0xC0,
	SOF1  = 0xC1,
	SOF2  = 0xC2,
	SOF3  = 0xC3,
	DHT   = 0xC4,
	SOF5  = 0xC5,
	SOF6  = 0xC6,
	SOF7  = 0xC7,
	SOF9  = 0xC9,
	SOF10 = 0xCA,
	SOF11 = 0xCB,
	SOF13 = 0xCD,
	SOF14 = 0xCE,
	SOF15 = 0xCF,
	RST0  = 0xD0,
	RST1  = 0xD1,
	RST2  = 0xD2,
	RST3  = 0xD3,
	RST4  = 0xD4,
	RST5  = 0xD5,
	RST6  = 0xD6,
	RST7  = 0xD7,
	SOI   = 0xD8,
	EOI   = 0xD9,
	SOS   = 0xDA,
	DQT   = 0xDB,
	DRI   = 0xDD,
}

// A cursor over the marker-segment portions of the stream (i.e.
// everything outside of a scan's entropy coded data).
Byte_Reader :: struct {
	data:     []u8,
	position: int,
}

read_u8 :: proc(reader: ^Byte_Reader) -> (value: u8, error: Error) {
	if reader.position >= len(reader.data) {
		return 0, .Corrupt_Stream
	}
	value = reader.data[reader.position]
	reader.position += 1
	return value, .None
}

read_u16be :: proc(reader: ^Byte_Reader) -> (value: u16, error: Error) {
	high_byte := read_u8(reader) or_return
	low_byte := read_u8(reader) or_return
	return u16(high_byte) << 8 | u16(low_byte), .None
}

read_slice :: proc(reader: ^Byte_Reader, count: int) -> (value: []u8, error: Error) {
	if count < 0 || reader.position + count > len(reader.data) {
		return nil, .Corrupt_Stream
	}
	value = reader.data[reader.position:reader.position + count]
	reader.position += count
	return value, .None
}

skip_segment :: proc(reader: ^Byte_Reader) -> (error: Error) {
	length := read_u16be(reader) or_return
	if length < 2 {
		return .Corrupt_Stream
	}
	read_slice(reader, int(length) - 2) or_return
	return .None
}

Component_Info :: struct {
	id:                       u8,
	quantization_table_index: int,
}

Frame_Info :: struct {
	width:           int,
	height:          int,
	component_count: int,
	components:      [4]Component_Info,
}

parse_sof0 :: proc(reader: ^Byte_Reader) -> (frame: Frame_Info, error: Error) {
	read_u16be(reader) or_return // segment length

	precision := read_u8(reader) or_return
	if precision != 8 {
		return frame, .Unsupported_Feature
	}

	height := read_u16be(reader) or_return
	width := read_u16be(reader) or_return
	if width == 0 || height == 0 {
		return frame, .Corrupt_Stream
	}

	component_count := read_u8(reader) or_return
	if component_count == 0 {
		return frame, .Corrupt_Stream
	}
	if component_count > 4 {
		return frame, .Unsupported_Feature
	}

	frame.width = int(width)
	frame.height = int(height)
	frame.component_count = int(component_count)

	for component_index in 0..<int(component_count) {
		id := read_u8(reader) or_return
		sampling_factors := read_u8(reader) or_return
		horizontal_sampling := sampling_factors >> 4
		vertical_sampling := sampling_factors & 0x0F
		if horizontal_sampling != 1 || vertical_sampling != 1 {
			return frame, .Unsupported_Feature
		}

		quantization_table_index := read_u8(reader) or_return
		if quantization_table_index >= MAX_QUANTIZATION_TABLES {
			return frame, .Corrupt_Stream
		}

		frame.components[component_index] = Component_Info{
			id                       = id,
			quantization_table_index = int(quantization_table_index),
		}
	}

	return frame, .None
}

parse_dqt :: proc(reader: ^Byte_Reader, quantization_tables: ^[MAX_QUANTIZATION_TABLES]Quantization_Table) -> (error: Error) {
	length := read_u16be(reader) or_return
	remaining := int(length) - 2

	for remaining > 0 {
		precision_and_index := read_u8(reader) or_return
		precision := precision_and_index >> 4
		table_index := precision_and_index & 0x0F
		if table_index >= MAX_QUANTIZATION_TABLES {
			return .Corrupt_Stream
		}
		if precision != 0 {
			// 16-bit quantization table entries are out of scope.
			return .Unsupported_Feature
		}

		table_bytes := read_slice(reader, COEFFICIENTS_PER_BLOCK) or_return
		for value, coefficient_index in table_bytes {
			quantization_tables[table_index][coefficient_index] = u16(value)
		}

		remaining -= 1 + COEFFICIENTS_PER_BLOCK
	}
	return .None
}

parse_dht :: proc(reader: ^Byte_Reader, dc_tables: ^[MAX_HUFFMAN_TABLES]Huffman_Table, ac_tables: ^[MAX_HUFFMAN_TABLES]Huffman_Table) -> (error: Error) {
	length := read_u16be(reader) or_return
	remaining := int(length) - 2

	for remaining > 0 {
		table_class_and_index := read_u8(reader) or_return
		table_class := table_class_and_index >> 4
		table_index := table_class_and_index & 0x0F
		if table_class > 1 || table_index >= MAX_HUFFMAN_TABLES {
			return .Corrupt_Stream
		}

		code_length_counts := read_slice(reader, 16) or_return
		symbol_count := 0
		for count in code_length_counts {
			symbol_count += int(count)
		}
		if symbol_count > 256 {
			return .Corrupt_Stream
		}

		symbols := read_slice(reader, symbol_count) or_return
		table := build_huffman_table(code_length_counts, symbols) or_return
		if table_class == 0 {
			dc_tables[table_index] = table
		} else {
			ac_tables[table_index] = table
		}

		remaining -= 1 + 16 + symbol_count
	}
	return .None
}

parse_dri :: proc(reader: ^Byte_Reader) -> (restart_interval: int, error: Error) {
	read_u16be(reader) or_return // segment length, always 4
	interval := read_u16be(reader) or_return
	return int(interval), .None
}

Scan_Component :: struct {
	sof_index:      int,
	dc_table_index: int,
	ac_table_index: int,
}

// Parses the SOS header. Only single-scan images that interleave
// every frame component are supported, matching how BLP's 1x1
// sampling is always encoded in practice.
parse_sos :: proc(reader: ^Byte_Reader, frame: Frame_Info) -> (scan_components: [4]Scan_Component, error: Error) {
	read_u16be(reader) or_return // segment length

	component_count := read_u8(reader) or_return
	if int(component_count) != frame.component_count {
		return scan_components, .Unsupported_Feature
	}

	for scan_index in 0..<int(component_count) {
		id := read_u8(reader) or_return
		table_indices := read_u8(reader) or_return
		dc_table_index := table_indices >> 4
		ac_table_index := table_indices & 0x0F
		if dc_table_index >= MAX_HUFFMAN_TABLES || ac_table_index >= MAX_HUFFMAN_TABLES {
			return scan_components, .Corrupt_Stream
		}

		sof_index := -1
		for candidate_index in 0..<frame.component_count {
			if frame.components[candidate_index].id == id {
				sof_index = candidate_index
				break
			}
		}
		if sof_index == -1 {
			return scan_components, .Corrupt_Stream
		}

		scan_components[scan_index] = Scan_Component{
			sof_index      = sof_index,
			dc_table_index = int(dc_table_index),
			ac_table_index = int(ac_table_index),
		}
	}

	read_u8(reader) or_return // spectral selection start, unused in baseline
	read_u8(reader) or_return // spectral selection end, unused in baseline
	read_u8(reader) or_return // successive approximation, unused in baseline

	return scan_components, .None
}

// Canonical Huffman decoding table built from the code-length counts
// and symbol list of a DHT segment, using the min-code/max-code/
// value-offset scheme of ITU T.81 Annex F.2.2.3.
Huffman_Table :: struct {
	min_code:     [17]int,
	max_code:     [17]int, // -1 means no codes of this length
	value_offset: [17]int,
	symbols:      [256]u8,
}

build_huffman_table :: proc(code_length_counts: []u8, symbols: []u8) -> (table: Huffman_Table, error: Error) {
	copy(table.symbols[:len(symbols)], symbols)

	code := 0
	symbol_index := 0
	for code_length in 1..=16 {
		count := int(code_length_counts[code_length - 1])
		if count == 0 {
			table.max_code[code_length] = -1
		} else {
			table.value_offset[code_length] = symbol_index - code
			table.min_code[code_length] = code
			code += count
			table.max_code[code_length] = code - 1
			symbol_index += count
		}
		code <<= 1
	}

	return table, .None
}

decode_huffman_symbol :: proc(reader: ^Bit_Reader, table: ^Huffman_Table) -> (symbol: u8, error: Error) {
	code := 0
	for code_length in 1..=16 {
		bit := read_bit(reader) or_return
		code = (code << 1) | int(bit)
		if table.max_code[code_length] != -1 && code >= table.min_code[code_length] && code <= table.max_code[code_length] {
			return table.symbols[code + table.value_offset[code_length]], .None
		}
	}
	return 0, .Corrupt_Stream
}

// A bit-level cursor over a scan's entropy coded data. 0xFF 0x00 byte
// stuffing is removed transparently; any 0xFF followed by a byte
// other than 0x00 ends the entropy data (restart markers are handled
// explicitly by the caller via consume_restart_marker, never here).
Bit_Reader :: struct {
	data:      []u8,
	position:  int,
	buffer:    u8,
	bit_count: int,
	at_marker: bool,
}

next_entropy_byte :: proc(reader: ^Bit_Reader) -> (value: u8, error: Error) {
	if reader.at_marker || reader.position >= len(reader.data) {
		return 0, .Corrupt_Stream
	}

	value = reader.data[reader.position]
	if value == 0xFF {
		if reader.position + 1 >= len(reader.data) {
			return 0, .Corrupt_Stream
		}
		next_byte := reader.data[reader.position + 1]
		if next_byte == 0x00 {
			reader.position += 2
			return 0xFF, .None
		}
		reader.at_marker = true
		return 0, .Corrupt_Stream
	}

	reader.position += 1
	return value, .None
}

read_bit :: proc(reader: ^Bit_Reader) -> (bit: u8, error: Error) {
	if reader.bit_count == 0 {
		reader.buffer = next_entropy_byte(reader) or_return
		reader.bit_count = 8
	}
	reader.bit_count -= 1
	bit = (reader.buffer >> uint(reader.bit_count)) & 1
	return bit, .None
}

read_bits :: proc(reader: ^Bit_Reader, count: int) -> (value: int, error: Error) {
	for _ in 0..<count {
		bit := read_bit(reader) or_return
		value = (value << 1) | int(bit)
	}
	return value, .None
}

byte_align :: proc(reader: ^Bit_Reader) {
	// Any bits still buffered here are trailing 1-padding the encoder
	// inserted to reach the byte boundary before the restart marker.
	reader.buffer = 0
	reader.bit_count = 0
}

consume_restart_marker :: proc(reader: ^Bit_Reader) -> (error: Error) {
	byte_align(reader)
	if reader.position + 1 >= len(reader.data) {
		return .Corrupt_Stream
	}
	if reader.data[reader.position] != 0xFF {
		return .Corrupt_Stream
	}
	marker := cast(Marker)reader.data[reader.position + 1]
	if marker < .RST0 || marker > .RST7 {
		return .Corrupt_Stream
	}
	reader.position += 2
	reader.at_marker = false
	return .None
}

// The EXTEND procedure of ITU T.81 Annex F.2.2.1: recovers the signed
// coefficient value from its magnitude category and coded bits.
extend_coefficient :: proc(value: int, category: int) -> int {
	if category == 0 {
		return 0
	}
	if value < (1 << uint(category - 1)) {
		return value - (1 << uint(category)) + 1
	}
	return value
}

// Decodes one 8x8 block's coefficients (DC predictor difference plus
// AC run/size pairs), dequantizes them, and un-zigzags them into
// natural (row-major) order. IDCT and level shift happen separately.
decode_block :: proc(
	reader: ^Bit_Reader,
	dc_table: ^Huffman_Table,
	ac_table: ^Huffman_Table,
	quantization_table: ^Quantization_Table,
	previous_dc: ^int,
) -> (block: [COEFFICIENTS_PER_BLOCK]f32, error: Error) {
	dc_category := decode_huffman_symbol(reader, dc_table) or_return
	if int(dc_category) > MAX_DC_CATEGORY {
		return block, .Corrupt_Stream
	}
	dc_bits := read_bits(reader, int(dc_category)) or_return
	previous_dc^ += extend_coefficient(dc_bits, int(dc_category))
	block[0] = f32(previous_dc^ * int(quantization_table[0]))

	scan_index := 1
	for scan_index < COEFFICIENTS_PER_BLOCK {
		symbol := decode_huffman_symbol(reader, ac_table) or_return
		if symbol == 0x00 {
			break // EOB: every remaining coefficient is zero.
		}

		run_length := int(symbol >> 4)
		category := int(symbol & 0x0F)
		// A run_length/category of 15/0 is ZRL, a run of 16 zeros; the
		// general handling below already accounts for it correctly,
		// since reading a zero-bit-length coefficient contributes 0.
		scan_index += run_length
		if scan_index >= COEFFICIENTS_PER_BLOCK || category > MAX_AC_CATEGORY {
			return block, .Corrupt_Stream
		}

		coefficient_bits := read_bits(reader, category) or_return
		coefficient := extend_coefficient(coefficient_bits, category)
		natural_index := zigzag_order[scan_index]
		block[natural_index] = f32(coefficient * int(quantization_table[scan_index]))
		scan_index += 1
	}

	return block, .None
}

// cos((2x+1) * u * PI / 16) for spatial position x and frequency u.
Cosine_Table :: [BLOCK_SIZE][BLOCK_SIZE]f32

build_cosine_table :: proc() -> (table: Cosine_Table) {
	for x in 0..<BLOCK_SIZE {
		for u in 0..<BLOCK_SIZE {
			table[x][u] = math.cos_f32((2.0 * f32(x) + 1.0) * f32(u) * math.PI / 16.0)
		}
	}
	return table
}

// The classic separable 1D IDCT of ITU T.81 Annex A.3.3, applied
// along one axis of a block: input is 8 frequency coefficients,
// output is 8 spatial samples.
idct_1d :: proc(input: [BLOCK_SIZE]f32, cosine_table: ^Cosine_Table) -> (output: [BLOCK_SIZE]f32) {
	for x in 0..<BLOCK_SIZE {
		sum: f32 = 0
		for u in 0..<BLOCK_SIZE {
			coefficient_scale: f32 = 1.0
			if u == 0 {
				coefficient_scale = INVERSE_SQRT2
			}
			sum += coefficient_scale * input[u] * cosine_table[x][u]
		}
		output[x] = sum * 0.5
	}
	return output
}

// Applies the 2D IDCT to `block` in place via two 1D passes (rows,
// then columns), each carrying half of the 1/4 normalization factor.
idct_8x8 :: proc(block: ^[COEFFICIENTS_PER_BLOCK]f32, cosine_table: ^Cosine_Table) {
	temp: [COEFFICIENTS_PER_BLOCK]f32

	for row in 0..<BLOCK_SIZE {
		input: [BLOCK_SIZE]f32
		for u in 0..<BLOCK_SIZE {
			input[u] = block[row * BLOCK_SIZE + u]
		}
		row_output := idct_1d(input, cosine_table)
		for x in 0..<BLOCK_SIZE {
			temp[row * BLOCK_SIZE + x] = row_output[x]
		}
	}

	for column in 0..<BLOCK_SIZE {
		input: [BLOCK_SIZE]f32
		for v in 0..<BLOCK_SIZE {
			input[v] = temp[v * BLOCK_SIZE + column]
		}
		column_output := idct_1d(input, cosine_table)
		for y in 0..<BLOCK_SIZE {
			block[y * BLOCK_SIZE + column] = column_output[y]
		}
	}
}

// Level-shifts, clamps, and writes the visible samples of an
// IDCT'd block into `plane`, clipping against the image edges for
// blocks that overhang a non-multiple-of-8 width or height.
write_block_to_plane :: proc(plane: []u8, width: int, height: int, block_column: int, block_row: int, block: ^[COEFFICIENTS_PER_BLOCK]f32) {
	origin_x := block_column * BLOCK_SIZE
	origin_y := block_row * BLOCK_SIZE
	visible_width := min(BLOCK_SIZE, width - origin_x)
	visible_height := min(BLOCK_SIZE, height - origin_y)

	for y in 0..<visible_height {
		for x in 0..<visible_width {
			shifted := block[y * BLOCK_SIZE + x] + 128.0
			clamped := clamp(shifted, 0.0, 255.0)
			plane[(origin_y + y) * width + (origin_x + x)] = u8(math.round_f32(clamped))
		}
	}
}

decode_entropy_coded_data :: proc(
	stream: []u8,
	start_position: int,
	frame: Frame_Info,
	scan_components: [4]Scan_Component,
	quantization_tables: ^[MAX_QUANTIZATION_TABLES]Quantization_Table,
	dc_huffman_tables: ^[MAX_HUFFMAN_TABLES]Huffman_Table,
	ac_huffman_tables: ^[MAX_HUFFMAN_TABLES]Huffman_Table,
	restart_interval: int,
	allocator: runtime.Allocator,
) -> (result: Decoded_Planes, error: Error) {
	result.width = frame.width
	result.height = frame.height
	result.component_count = frame.component_count
	result.allocator = allocator
	for component_index in 0..<frame.component_count {
		result.planes[component_index] = make([]u8, frame.width * frame.height, allocator)
	}
	defer if error != .None {
		destroy(&result)
	}

	cosine_table := build_cosine_table()
	bit_reader := Bit_Reader{data = stream, position = start_position}
	previous_dc: [4]int

	block_columns := (frame.width + BLOCK_SIZE - 1) / BLOCK_SIZE
	block_rows := (frame.height + BLOCK_SIZE - 1) / BLOCK_SIZE
	total_mcus := block_columns * block_rows

	for mcu_index in 0..<total_mcus {
		if restart_interval > 0 && mcu_index > 0 && mcu_index % restart_interval == 0 {
			consume_restart_marker(&bit_reader) or_return
			previous_dc = {}
		}

		block_row := mcu_index / block_columns
		block_column := mcu_index % block_columns

		for scan_index in 0..<frame.component_count {
			scan_component := scan_components[scan_index]
			dc_table := &dc_huffman_tables[scan_component.dc_table_index]
			ac_table := &ac_huffman_tables[scan_component.ac_table_index]
			quantization_table := &quantization_tables[frame.components[scan_component.sof_index].quantization_table_index]

			block := decode_block(&bit_reader, dc_table, ac_table, quantization_table, &previous_dc[scan_component.sof_index]) or_return
			idct_8x8(&block, &cosine_table)
			write_block_to_plane(result.planes[scan_component.sof_index], frame.width, frame.height, block_column, block_row, &block)
		}
	}

	return result, .None
}
