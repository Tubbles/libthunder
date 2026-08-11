package gamedata

// Loading the base gameplay SLK tables, driven by the metadata: every
// metadata row that names a table is read out of that table's column,
// for every object the row applies to.
//
// Rows whose key cell is blank are skipped (AbilityData.slk carries 4
// junk rows, AbilityBuffData.slk declares 480 rows of which 243 are
// entirely empty), and `-`, `_` and never-written cells all mean
// "unset" and store nothing.

import "base:runtime"
import "core:strings"
import slk "thunder:formats/slk"

// The metadata's `repeat` is file supplied, so the number of level
// slots read per field is capped before anything is allocated. The
// stock tables top out at 10 (Doodads.slk's vertex colours).
MAXIMUM_TABLE_REPEAT :: 64

// Reads one base table into the database. The table argument decides
// the object family, so the caller must pass the table the member
// actually is (see TABLE_MEMBERS).
load_table :: proc(database: ^Database, table: Table, content: string) -> Error {
	kind, kind_known := kind_for_table(table)
	if !kind_known {
		return .Unknown_Table
	}
	parsed, parse_error := slk.parse(content, database.allocator)
	defer slk.destroy(&parsed)
	if parse_error != .None || parsed.row_count < 2 {
		return .Invalid_Table
	}

	columns := make_column_index(&parsed, database.allocator)
	defer destroy_column_index(&columns, database.allocator)
	key_column := find_key_column(&columns, table, database.allocator)

	rows := make(map[[4]u8]int, database.allocator)
	defer delete(rows)
	keys := make([dynamic][4]u8, 0, parsed.row_count, database.allocator)
	defer delete(keys)
	for row in 1 ..< parsed.row_count {
		key, key_ok := rawcode(strings.trim_space(cell_string(&parsed, row, key_column)))
		if !key_ok || key in rows {
			continue
		}
		rows[key] = row
		append(&keys, key)
	}

	slots: [MAXIMUM_TABLE_REPEAT]int
	for &descriptor in database.metadata.descriptors {
		if descriptor.table != table {
			continue
		}
		slot_count := resolve_column_slots(&descriptor, &columns, slots[:], database.allocator)
		if slot_count == 0 {
			continue
		}
		if len(descriptor.use_specific) > 0 {
			for code in descriptor.use_specific {
				row, found := rows[code]
				if !found {
					continue
				}
				read_table_row(database, kind, code, &descriptor, &parsed, slots[:slot_count], row)
			}
			continue
		}
		for key in keys {
			if !descriptor_applies_to_object(&descriptor, key) {
				continue
			}
			read_table_row(database, kind, key, &descriptor, &parsed, slots[:slot_count], rows[key])
		}
	}
	return .None
}

// Fills `slots` with the column index per level slot and returns how
// many slots were resolved: one for a single-valued field, `repeat`
// for a leveled one. A column the table does not have contributes -1,
// so a partially present family still reads what is there.
@(private)
resolve_column_slots :: proc(
	descriptor: ^Field_Descriptor,
	columns: ^map[string]int,
	slots: []int,
	allocator: runtime.Allocator,
) -> (
	count: int,
) {
	if descriptor.repeat <= 0 {
		lowered := strings.to_lower(descriptor.column, allocator)
		defer delete(lowered, allocator)
		index, found := columns[lowered]
		if !found {
			return 0
		}
		slots[0] = index
		return 1
	}
	count = min(descriptor.repeat, MAXIMUM_TABLE_REPEAT, len(slots))
	resolved := 0
	for level in 1 ..= count {
		name := column_name_for_level(descriptor, level, allocator)
		defer delete(name, allocator)
		lowered := strings.to_lower(name, allocator)
		defer delete(lowered, allocator)
		index, found := columns[lowered]
		slots[level - 1] = index if found else -1
		if found {
			resolved += 1
		}
	}
	if resolved == 0 {
		return 0
	}
	return count
}

@(private)
read_table_row :: proc(
	database: ^Database,
	kind: Object_Kind,
	key: [4]u8,
	descriptor: ^Field_Descriptor,
	parsed: ^slk.Table,
	slots: []int,
	row: int,
) {
	for column, slot in slots {
		if column < 0 {
			continue
		}
		value, has_value := table_value(slk.cell(parsed, row, column), database.allocator)
		if !has_value {
			continue
		}
		level := 0 if descriptor.repeat <= 0 else slot + 1
		object := ensure_object(database, kind, key)
		if set_field_value(object, descriptor.id, level, value, database.allocator) {
			database.stats.table_values += 1
		}
	}
}

// SLK cells carry three shapes of "no value": a cell the writer never
// emitted, and the placeholder strings `-` and `_`, which the stock
// tables sometimes pad with spaces (UnitBalance's ` - `). Real values
// keep their own surrounding spaces (Doodads.slk has ` Ruins Stones`),
// so only the placeholder test trims.
@(private)
table_value :: proc(cell: slk.Cell_Value, allocator: runtime.Allocator) -> (value: Value, ok: bool) {
	switch stored in cell {
	case i64:
		return stored, true
	case f64:
		return stored, true
	case string:
		if is_unset_placeholder(stored) {
			return nil, false
		}
		return strings.clone(stored, allocator), true
	}
	return nil, false
}

is_unset_placeholder :: proc(text: string) -> bool {
	trimmed := strings.trim_space(text)
	return len(trimmed) == 0 || trimmed == "-" || trimmed == "_"
}

@(private)
find_key_column :: proc(columns: ^map[string]int, table: Table, allocator: runtime.Allocator) -> int {
	names := TABLE_KEY_COLUMNS
	name := names[table]
	if len(name) == 0 {
		return 0
	}
	lowered := strings.to_lower(name, allocator)
	defer delete(lowered, allocator)
	index, found := columns[lowered]
	if !found {
		// Every stock table keys on column 0; the named column is the
		// documented spelling, not a requirement.
		return 0
	}
	return index
}

// Lowercased column name to column index, built from the SLK's header
// row. Member names and column names are matched case insensitively
// throughout (`Units\unitUI.slk`, metadata `CasterArt` against the TXT
// key `Casterart`); only modification ids are case sensitive.
@(private)
make_column_index :: proc(parsed: ^slk.Table, allocator: runtime.Allocator) -> (columns: map[string]int) {
	columns = make(map[string]int, allocator)
	for column in 0 ..< parsed.column_count {
		text, is_text := slk.cell_text(parsed, 0, column)
		if !is_text {
			continue
		}
		name := strings.to_lower(strings.trim_space(text), allocator)
		if len(name) == 0 || name in columns {
			delete(name, allocator)
			continue
		}
		columns[name] = column
	}
	return columns
}

@(private)
destroy_column_index :: proc(columns: ^map[string]int, allocator: runtime.Allocator) {
	for name in columns {
		delete(name, allocator)
	}
	delete(columns^)
}

@(private)
cell_string :: proc(parsed: ^slk.Table, row: int, column: int) -> string {
	text, is_text := slk.cell_text(parsed, row, column)
	if !is_text {
		return ""
	}
	return text
}

@(private)
column_string :: proc(parsed: ^slk.Table, columns: ^map[string]int, row: int, name: string) -> string {
	column, found := columns[name]
	if !found {
		return ""
	}
	return cell_string(parsed, row, column)
}

@(private)
column_integer :: proc(parsed: ^slk.Table, columns: ^map[string]int, row: int, name: string, fallback: int) -> int {
	column, found := columns[name]
	if !found {
		return fallback
	}
	switch stored in slk.cell(parsed, row, column) {
	case i64:
		return int(stored)
	case f64:
		return int(stored)
	case string:
		number, parse_ok := value_integer(Value(strings.trim_space(stored)))
		if !parse_ok {
			return fallback
		}
		return int(number)
	}
	return fallback
}
