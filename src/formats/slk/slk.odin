package slk

// SYLK (SLK) table parser for WC3's gameplay data files
// (Units\UnitData.slk and friends). The subset WC3 uses: ID header,
// B bounds, C cell records with sticky row/column, E end. Reference:
// Microsoft's sylksum document and the community write-ups cited in
// docs/research/file-formats.md.

import "base:runtime"
import "core:strconv"
import "core:strings"

Error :: enum {
	None,
	Missing_Header,
	Missing_Bounds,
	Invalid_Bounds,
	Cell_Out_Of_Bounds,
	Malformed_Record,
}

Cell_Value :: union {
	i64,
	f64,
	string,
}

Table :: struct {
	column_count: int,
	row_count:    int,
	// Row-major; nil means the cell was never set.
	cells:        []Cell_Value,
	allocator:    runtime.Allocator,
}

destroy :: proc(table: ^Table) {
	if table.cells == nil {
		table^ = {}
		return
	}
	for cell in table.cells {
		if text, is_string := cell.(string); is_string {
			delete(text, table.allocator)
		}
	}
	delete(table.cells, table.allocator)
	table^ = {}
}

cell :: proc(table: ^Table, row: int, column: int) -> Cell_Value {
	if row < 0 || row >= table.row_count || column < 0 || column >= table.column_count {
		return nil
	}
	return table.cells[row * table.column_count + column]
}

cell_text :: proc(table: ^Table, row: int, column: int) -> (text: string, is_string: bool) {
	return cell(table, row, column).(string)
}

// On error the returned table is empty; the partially built one is
// freed internally. (Odin defers cannot patch results after copy-out,
// so error paths must return an empty table explicitly.)
parse :: proc(content: string, allocator := context.allocator) -> (result: Table, error: Error) {
	table: Table
	table.allocator = allocator
	defer if error != .None {
		destroy(&table)
	}

	saw_header := false
	current_row := -1
	current_column := -1
	fields := make([dynamic]string, allocator)
	defer {
		for field in fields {
			delete(field, allocator)
		}
		delete(fields)
	}

	remaining := content
	for raw_line in strings.split_lines_iterator(&remaining) {
		line := strings.trim_right(raw_line, "\r")
		if len(line) == 0 {
			continue
		}

		split_record_fields(line, &fields, allocator) or_return
		if len(fields) == 0 {
			continue
		}
		record_type := fields[0]

		switch record_type {
		case "ID":
			saw_header = true
		case "B":
			if !saw_header {
				return {}, .Missing_Header
			}
			// Bounds must precede cells for preallocation; WC3's own
			// files always follow this order.
			bounds_error := parse_bounds(&table, fields[1:])
			if bounds_error != .None {
				return {}, bounds_error
			}
		case "C":
			if !saw_header {
				return {}, .Missing_Header
			}
			if table.cells == nil {
				return {}, .Missing_Bounds
			}
			cell_error := parse_cell(&table, fields[1:], &current_row, &current_column, allocator)
			if cell_error != .None {
				return {}, cell_error
			}
		case "E":
			return table, .None
		case:
			// F (formatting), O (options), and anything else WC3's own
			// parser has no use for is skipped.
		}
		for field in fields {
			delete(field, allocator)
		}
		clear(&fields)
	}

	if !saw_header {
		return {}, .Missing_Header
	}
	return table, .None
}

@(private)
parse_bounds :: proc(table: ^Table, fields: []string) -> Error {
	column_count := 0
	row_count := 0
	for field in fields {
		if len(field) < 2 {
			continue
		}
		value, parse_ok := strconv.parse_int(field[1:])
		if !parse_ok {
			continue
		}
		switch field[0] {
		case 'X':
			column_count = value
		case 'Y':
			row_count = value
		}
	}
	if column_count <= 0 || row_count <= 0 || column_count > 4096 || row_count > 1_000_000 {
		return .Invalid_Bounds
	}
	table.column_count = column_count
	table.row_count = row_count
	table.cells = make([]Cell_Value, column_count * row_count, table.allocator)
	return .None
}

@(private)
parse_cell :: proc(table: ^Table, fields: []string, current_row: ^int, current_column: ^int, allocator: runtime.Allocator) -> Error {
	value_field := ""
	saw_value := false
	for field in fields {
		if len(field) < 1 {
			continue
		}
		switch field[0] {
		case 'X':
			column, parse_ok := strconv.parse_int(field[1:])
			if !parse_ok {
				return .Malformed_Record
			}
			current_column^ = column - 1
		case 'Y':
			row, parse_ok := strconv.parse_int(field[1:])
			if !parse_ok {
				return .Malformed_Record
			}
			current_row^ = row - 1
		case 'K':
			value_field = field[1:]
			saw_value = true
		}
	}
	if !saw_value {
		// Position-only records just move the cursor.
		return .None
	}
	if current_row^ < 0 || current_row^ >= table.row_count ||
	   current_column^ < 0 || current_column^ >= table.column_count {
		// The real engine is crash-prone here; we surface it instead
		// (see WI-0007 strictness note).
		return .Cell_Out_Of_Bounds
	}

	cell_index := current_row^ * table.column_count + current_column^
	if previous, is_string := table.cells[cell_index].(string); is_string {
		delete(previous, table.allocator)
	}
	table.cells[cell_index] = parse_value(value_field, allocator)
	return .None
}

@(private)
parse_value :: proc(field: string, allocator: runtime.Allocator) -> Cell_Value {
	if len(field) >= 2 && field[0] == '"' && field[len(field) - 1] == '"' {
		return strings.clone(field[1:len(field) - 1], allocator)
	}
	if integer_value, integer_ok := strconv.parse_i64(field); integer_ok {
		return integer_value
	}
	if float_value, float_ok := strconv.parse_f64(field); float_ok {
		return float_value
	}
	if field == "TRUE" {
		return i64(1)
	}
	if field == "FALSE" {
		return i64(0)
	}
	return strings.clone(field, allocator)
}

// Split one record line on ';', honoring the SYLK ";;" escape for a
// literal semicolon inside a field. Returns cloned field strings.
@(private)
split_record_fields :: proc(line: string, fields: ^[dynamic]string, allocator: runtime.Allocator) -> Error {
	builder := strings.builder_make(allocator)
	defer strings.builder_destroy(&builder)

	flush :: proc(builder: ^strings.Builder, fields: ^[dynamic]string, allocator: runtime.Allocator) {
		append(fields, strings.clone(strings.to_string(builder^), allocator))
		strings.builder_reset(builder)
	}

	index := 0
	for index < len(line) {
		character := line[index]
		if character == ';' {
			if index + 1 < len(line) && line[index + 1] == ';' {
				strings.write_byte(&builder, ';')
				index += 2
				continue
			}
			flush(&builder, fields, allocator)
			index += 1
			continue
		}
		strings.write_byte(&builder, character)
		index += 1
	}
	flush(&builder, fields, allocator)
	return .None
}
