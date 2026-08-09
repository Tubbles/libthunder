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
stray_lines_are_skipped :: proc(t: ^testing.T) {
	file := parse("orphan=1\ngarbage line\n[S]\nkey=v\n")
	defer destroy(&file)

	testing.expect_value(t, len(file.sections), 1)
	value, found := lookup(&file, "S", "key")
	testing.expect(t, found)
	testing.expect_value(t, value, "v")
}
