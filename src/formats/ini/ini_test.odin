package ini

import "core:testing"

@(private = "file")
SAMPLE :: `// gameplay constants
[Misc]
AttackHalfAngle=45
BuildingAngle = 270
// comment inside a section
StructureDecayTime=88.5

[Terrain]
MaxSlope=90
AttackHalfAngle=60
`

@(test)
parses_sections_and_keys :: proc(t: ^testing.T) {
	file := parse(SAMPLE)
	defer destroy(&file)

	testing.expect_value(t, len(file.sections), 2)

	value, found := lookup(&file, "Misc", "AttackHalfAngle")
	testing.expect(t, found)
	testing.expect_value(t, value, "45")

	value, found = lookup(&file, "Terrain", "AttackHalfAngle")
	testing.expect(t, found)
	testing.expect_value(t, value, "60")

	value, found = lookup(&file, "Misc", "BuildingAngle")
	testing.expect(t, found)
	testing.expect_value(t, value, "270")

	_, found = lookup(&file, "Misc", "NoSuchKey")
	testing.expect(t, !found)
	_, found = lookup(&file, "NoSuchSection", "AttackHalfAngle")
	testing.expect(t, !found)
}

@(test)
lookup_is_case_insensitive :: proc(t: ^testing.T) {
	file := parse(SAMPLE)
	defer destroy(&file)

	value, found := lookup(&file, "misc", "attackhalfangle")
	testing.expect(t, found)
	testing.expect_value(t, value, "45")
}

@(test)
duplicate_keys_last_wins :: proc(t: ^testing.T) {
	file := parse("[A]\nkey=1\nkey=2\n")
	defer destroy(&file)

	value, found := lookup(&file, "A", "key")
	testing.expect(t, found)
	testing.expect_value(t, value, "2")
}

@(test)
utf8_bom_does_not_hide_first_section :: proc(t: ^testing.T) {
	file := parse("\xef\xbb\xbf[First]\nkey=1\n[Second]\nother=2\n")
	defer destroy(&file)

	testing.expect_value(t, len(file.sections), 2)
	value, found := lookup(&file, "First", "key")
	testing.expect(t, found)
	testing.expect_value(t, value, "1")
}

// Whitespace around a value is part of the value in WC3's profile TXT
// files; the sample below is Units\HumanAbilityStrings.txt's
// [Afbk] EditorSuffix, the corpus case that motivated the option.
@(test)
preserved_values_keep_surrounding_spaces :: proc(t: ^testing.T) {
	sample := "[Afbk]\nEditorSuffix= (Spell Breaker)\nTrailing=value \nBoth=  padded  \n"

	file := parse(sample, context.allocator, Options{preserve_value_whitespace = true})
	defer destroy(&file)

	value, found := lookup(&file, "Afbk", "EditorSuffix")
	testing.expect(t, found)
	testing.expect_value(t, value, " (Spell Breaker)")

	value, found = lookup(&file, "Afbk", "Trailing")
	testing.expect(t, found)
	testing.expect_value(t, value, "value ")

	value, found = lookup(&file, "Afbk", "Both")
	testing.expect(t, found)
	testing.expect_value(t, value, "  padded  ")
}

// The same input through the default path, which every pre-WI-0015
// caller uses.
@(test)
default_parse_still_trims_values :: proc(t: ^testing.T) {
	sample := "[Afbk]\nEditorSuffix= (Spell Breaker)\nTrailing=value \nBoth=  padded  \n"

	file := parse(sample)
	defer destroy(&file)

	value, found := lookup(&file, "Afbk", "EditorSuffix")
	testing.expect(t, found)
	testing.expect_value(t, value, "(Spell Breaker)")

	value, found = lookup(&file, "Afbk", "Trailing")
	testing.expect(t, found)
	testing.expect_value(t, value, "value")

	value, found = lookup(&file, "Afbk", "Both")
	testing.expect(t, found)
	testing.expect_value(t, value, "padded")
}

// Keys, section headers and comments are unaffected by the option:
// only the bytes after the '=' change.
@(test)
preserved_parse_keeps_structure :: proc(t: ^testing.T) {
	sample := "  [Padded]  \n  key  =  value  \n  // indented comment\n\t\n"

	file := parse(sample, context.allocator, Options{preserve_value_whitespace = true})
	defer destroy(&file)

	testing.expect_value(t, len(file.sections), 1)
	testing.expect_value(t, file.sections[0].name, "Padded")
	testing.expect_value(t, len(file.sections[0].entries), 1)
	testing.expect_value(t, file.sections[0].entries[0].key, "key")
	testing.expect_value(t, file.sections[0].entries[0].value, "  value  ")
}

@(test)
stray_lines_are_skipped :: proc(t: ^testing.T) {
	file := parse("orphan=1\ngarbage line\n[S]\nkey=v\n")
	defer destroy(&file)

	testing.expect_value(t, len(file.sections), 1)
	value, found := lookup(&file, "S", "key")
	testing.expect(t, found)
	testing.expect_value(t, value, "v")
}
