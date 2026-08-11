package ini

// Parser for WC3's INI-style TXT gameplay files (war3mapMisc.txt,
// UI\MiscData.txt and friends): [Section] headers, key=value pairs,
// // line comments. Order is preserved for future round-trip writing;
// duplicate keys keep the last value on lookup, matching how later
// entries override earlier ones in the game's own data loading
// (observed behavior, to be re-verified when the data layer consumes
// this; see WI-0007).
//
// Values are returned as written apart from surrounding whitespace,
// which is trimmed unless Options.preserve_value_whitespace is set.
// Quotes are never stripped and commas are never split: the gameplay
// data layer (thunder:gamedata) owns that grammar, because only the
// field's metadata says whether a value is one string, a packed
// element list, or one string per ability level.

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

// Parse behavior the default (WI-0007) callers do not want.
Options :: struct {
	// Keep every byte after the '=' as written, including leading and
	// trailing spaces. WC3's gameplay profile TXT files carry 394
	// values whose surrounding spaces are part of the value
	// (`EditorSuffix= (Spell Breaker)` in Units\HumanAbilityStrings.txt
	// is the clearest one; WI-0015 survey). The default trims them,
	// which is what a settings-style reader wants and what every
	// pre-WI-0015 caller expects, so the raw form is opt in.
	preserve_value_whitespace: bool,
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

parse :: proc(content: string, allocator := context.allocator, options := Options{}) -> (file: File) {
	file.allocator = allocator
	file.sections = make([dynamic]Section, allocator)

	// Third-party tools save TXT files with a UTF-8 BOM, which
	// trim_space does not strip and which would otherwise hide the
	// first section header (review finding, WI-0007 log).
	remaining := strings.trim_prefix(content, "\xef\xbb\xbf")
	for raw_line in strings.split_lines_iterator(&remaining) {
		// Only the left side is trimmed here so that a preserved value
		// keeps its trailing spaces (the iterator has already dropped a
		// trailing CR). The key and the default-mode value are trimmed
		// individually below, which leaves the structural decisions and
		// both trimmed results identical to a plain trim_space of the
		// whole line.
		line := strings.trim_left_space(raw_line)
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
		value := line[equals_index + 1:]
		if !options.preserve_value_whitespace {
			value = strings.trim_space(value)
		}
		entry := Entry {
			key   = strings.clone(strings.trim_space(line[:equals_index]), allocator),
			value = strings.clone(value, allocator),
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
