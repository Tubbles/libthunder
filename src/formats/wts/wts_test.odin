package wts

// Synthetic-fixture tests: hand-written wts text, no game data.

import "core:testing"

@(test)
basic_entries_decode :: proc(t: ^testing.T) {
	content := "STRING 0\n{\nHello\n}\n\nSTRING 7\n// a comment\n{\nWorld\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(table.entries), 2)
	first, first_found := lookup(&table, 0)
	testing.expect_value(t, first_found, true)
	testing.expect_value(t, first, "Hello")
	second, second_found := lookup(&table, 7)
	testing.expect_value(t, second_found, true)
	testing.expect_value(t, second, "World")
}

@(test)
utf8_byte_order_mark_is_stripped :: proc(t: ^testing.T) {
	content := "\xef\xbb\xbfSTRING 1\n{\nBody\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, found := lookup(&table, 1)
	testing.expect_value(t, found, true)
	testing.expect_value(t, value, "Body")
}

@(test)
carriage_return_line_endings_decode :: proc(t: ^testing.T) {
	content := "STRING 3\r\n{\r\nBooty Bay\r\n}\r\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, found := lookup(&table, 3)
	testing.expect_value(t, found, true)
	testing.expect_value(t, value, "Booty Bay")
}

@(test)
leading_zeros_and_whitespace_in_key_decode :: proc(t: ^testing.T) {
	content := "STRING  007 \n{\nBond\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, found := lookup(&table, 7)
	testing.expect_value(t, found, true)
	testing.expect_value(t, value, "Bond")
}

// Mirrored from War3Net: a key that fails to parse as a number
// becomes key 0 rather than an error.
@(test)
unparsable_key_becomes_zero :: proc(t: ^testing.T) {
	content := "STRING x\n{\nFallback\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, found := lookup(&table, 0)
	testing.expect_value(t, found, true)
	testing.expect_value(t, value, "Fallback")
}

@(test)
multi_line_body_joins_with_newline :: proc(t: ^testing.T) {
	content := "STRING 2\n{\nline one\nline two\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, _ := lookup(&table, 2)
	testing.expect_value(t, value, "line one\nline two")
}

@(test)
multi_line_comment_before_brace_decodes :: proc(t: ^testing.T) {
	content := "STRING 4\n// first comment line\nsecond comment line\n{\nBody\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	value, found := lookup(&table, 4)
	testing.expect_value(t, found, true)
	testing.expect_value(t, value, "Body")
}

@(test)
duplicate_key_keeps_last :: proc(t: ^testing.T) {
	content := "STRING 5\n{\nfirst\n}\nSTRING 5\n{\nsecond\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(table.entries), 1)
	value, _ := lookup(&table, 5)
	testing.expect_value(t, value, "second")
}

@(test)
missing_opening_brace_is_rejected :: proc(t: ^testing.T) {
	content := "STRING 1\nnot a comment and not a brace\n{\nBody\n}\n"
	table, error := parse(content)
	testing.expect_value(t, error, Error.Missing_Opening_Brace)
	testing.expect_value(t, len(table.entries), 0)

	_, end_error := parse("STRING 1\n")
	testing.expect_value(t, end_error, Error.Missing_Opening_Brace)
}

@(test)
missing_closing_brace_is_rejected :: proc(t: ^testing.T) {
	content := "STRING 0\n{\nGood\n}\nSTRING 1\n{\nBody without an end\n"
	table, error := parse(content)
	testing.expect_value(t, error, Error.Missing_Closing_Brace)
	testing.expect_value(t, len(table.entries), 0)
}

@(test)
reference_keys_parse_leniently :: proc(t: ^testing.T) {
	key, is_reference := reference_key("TRIGSTR_003")
	testing.expect_value(t, is_reference, true)
	testing.expect_value(t, key, 3)

	zero_key, zero_is_reference := reference_key("TRIGSTR_000")
	testing.expect_value(t, zero_is_reference, true)
	testing.expect_value(t, zero_key, 0)

	_, garbage_is_reference := reference_key("TRIGSTR_abc")
	testing.expect_value(t, garbage_is_reference, false)

	_, empty_is_reference := reference_key("TRIGSTR_")
	testing.expect_value(t, empty_is_reference, false)

	_, plain_is_reference := reference_key("Just a name")
	testing.expect_value(t, plain_is_reference, false)
}

@(test)
resolve_returns_entry_or_input :: proc(t: ^testing.T) {
	content := "STRING 3\n{\nBooty Bay\n}\n"
	table, error := parse(content)
	defer destroy(&table)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, resolve(&table, "TRIGSTR_3"), "Booty Bay")
	testing.expect_value(t, resolve(&table, "TRIGSTR_003"), "Booty Bay")
	testing.expect_value(t, resolve(&table, "TRIGSTR_9"), "TRIGSTR_9")
	testing.expect_value(t, resolve(&table, "A literal name"), "A literal name")
}
