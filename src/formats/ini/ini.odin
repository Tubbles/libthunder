package ini

// Parser for WC3's INI-style TXT gameplay files (war3mapMisc.txt,
// UI\MiscData.txt and friends): [Section] headers, key=value pairs,
// // line comments. Order is preserved for future round-trip writing;
// duplicate keys keep the last value on lookup, matching how later
// entries override earlier ones in the game's own data loading
// (observed behavior, to be re-verified when the data layer consumes
// this; see WI-0007).

import "base:runtime"
import "core:strings"

Entry :: struct {
	key:   string,
	value: string,
}

Section :: struct {
	name:    string,
	entries: [dynamic]Entry,
}

File :: struct {
	sections:  [dynamic]Section,
	allocator: runtime.Allocator,
}

destroy :: proc(file: ^File) {
	for &section in file.sections {
		for entry in section.entries {
			delete(entry.key, file.allocator)
			delete(entry.value, file.allocator)
		}
		delete(section.entries)
		delete(section.name, file.allocator)
	}
	delete(file.sections)
	file^ = {}
}

parse :: proc(content: string, allocator := context.allocator) -> (file: File) {
	file.allocator = allocator
	file.sections = make([dynamic]Section, allocator)

	remaining := content
	for raw_line in strings.split_lines_iterator(&remaining) {
		line := strings.trim_space(raw_line)
		if len(line) == 0 || strings.has_prefix(line, "//") {
			continue
		}

		if line[0] == '[' {
			closing_index := strings.index_byte(line, ']')
			if closing_index <= 1 {
				continue
			}
			section := Section {
				name    = strings.clone(line[1:closing_index], allocator),
				entries = make([dynamic]Entry, allocator),
			}
			append(&file.sections, section)
			continue
		}

		equals_index := strings.index_byte(line, '=')
		if equals_index <= 0 || len(file.sections) == 0 {
			// Keys before any section, and non key=value junk, are
			// skipped rather than fatal: real Blizzard TXT files
			// contain stray lines.
			continue
		}
		entry := Entry {
			key   = strings.clone(strings.trim_space(line[:equals_index]), allocator),
			value = strings.clone(strings.trim_space(line[equals_index + 1:]), allocator),
		}
		append(&file.sections[len(file.sections) - 1].entries, entry)
	}
	return file
}

// Last occurrence wins, both for duplicate sections and duplicate keys.
lookup :: proc(file: ^File, section_name: string, key: string) -> (value: string, found: bool) {
	#reverse for &section in file.sections {
		if !strings.equal_fold(section.name, section_name) {
			continue
		}
		#reverse for entry in section.entries {
			if strings.equal_fold(entry.key, key) {
				return entry.value, true
			}
		}
	}
	return "", false
}
