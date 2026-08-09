package slk

import "core:testing"

@(private = "file")
BASIC_TABLE :: "ID;PWXL;N;E\r\nB;X3;Y2;D0\r\nC;X1;Y1;K\"unitID\"\r\nC;X2;K\"name\"\r\nC;X3;K123\r\nC;X1;Y2;K\"hfoo\"\r\nC;X2;K1.5\r\nE\r\n"

@(test)
parses_basic_table_with_sticky_row :: proc(t: ^testing.T) {
	table, error := parse(BASIC_TABLE)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, table.column_count, 3)
	testing.expect_value(t, table.row_count, 2)

	first, first_is_string := cell_text(&table, 0, 0)
	testing.expect(t, first_is_string)
	testing.expect_value(t, first, "unitID")

	name, name_is_string := cell_text(&table, 0, 1)
	testing.expect(t, name_is_string)
	testing.expect_value(t, name, "name")

	testing.expect_value(t, cell(&table, 0, 2), Cell_Value(i64(123)))
	testing.expect_value(t, cell(&table, 1, 1), Cell_Value(f64(1.5)))

	unit_id, unit_is_string := cell_text(&table, 1, 0)
	testing.expect(t, unit_is_string)
	testing.expect_value(t, unit_id, "hfoo")
}

@(test)
empty_cells_read_as_nil :: proc(t: ^testing.T) {
	table, error := parse(BASIC_TABLE)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, cell(&table, 1, 2), Cell_Value(nil))
	testing.expect_value(t, cell(&table, 5, 5), Cell_Value(nil))
}

@(test)
escaped_semicolons_survive :: proc(t: ^testing.T) {
	content := "ID;P\nB;X1;Y1\nC;X1;Y1;K\"a;;b\"\nE\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	text, is_string := cell_text(&table, 0, 0)
	testing.expect(t, is_string)
	testing.expect_value(t, text, "a;b")
}

@(test)
cell_outside_bounds_is_an_error :: proc(t: ^testing.T) {
	content := "ID;P\nB;X1;Y1\nC;X2;Y1;K\"overflow\"\nE\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.Cell_Out_Of_Bounds)
}

@(test)
missing_header_is_an_error :: proc(t: ^testing.T) {
	table, error := parse("B;X1;Y1\nC;X1;Y1;K1\nE\n")
	defer destroy(&table)
	testing.expect_value(t, error, Error.Missing_Header)
}

@(test)
cells_before_bounds_are_an_error :: proc(t: ^testing.T) {
	table, error := parse("ID;P\nC;X1;Y1;K1\nE\n")
	defer destroy(&table)
	testing.expect_value(t, error, Error.Missing_Bounds)
}
