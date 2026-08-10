package wts

// Parser for war3map.wts, the trigger-strings localization table of a
// Warcraft III map: plain text entries of the form
//
//     STRING <n>
//     // optional comment lines
//     {
//     body text (may span lines)
//     }
//
// "TRIGSTR_<n>" placeholders elsewhere (war3map.w3i, triggers, ...)
// resolve against this table. The format is version-less and has been
// stable since Reign of Chaos.
//
// Reference: War3Net's TriggerStrings text parser (MIT, license
// verified; docs/research/file-formats.md). Tolerances mirrored from
// it: keys parse with surrounding whitespace and leading zeros
// ("STRING 003" is key 3); a key that does not parse as a number at
// all becomes key 0 rather than an error; the brace lines must be
// exactly "{" and "}" (after stripping the line ending); any line
// between the STRING line and the opening brace is a comment, but
// only if the first such line starts with "//". Multi-line bodies are
// stored with "\n" separators regardless of the file's line endings.
//
// Corpus wts files may carry a UTF-8 byte order mark; it is stripped
// (same trap as the ini package, WI-0007).

import "base:runtime"
import "core:strconv"
import "core:strings"

Error :: enum {
	None,
	Missing_Opening_Brace,
	Missing_Closing_Brace,
}

REFERENCE_PREFIX :: "TRIGSTR_"

Trigger_Strings :: struct {
	// Duplicate keys keep the last entry, matching lookup order in
	// the game's own resolution.
	entries:   map[u32]string,
	allocator: runtime.Allocator,
}

destroy :: proc(trigger_strings: ^Trigger_Strings) {
	for _, value in trigger_strings.entries {
		delete(value, trigger_strings.allocator)
	}
	delete(trigger_strings.entries)
	trigger_strings^ = {}
}

// Parses a complete war3map.wts text. On error the partially built
// table is freed and a zero value is returned.
parse :: proc(content: string, allocator := context.allocator) -> (trigger_strings: Trigger_Strings, error: Error) {
	building: Trigger_Strings
	building.allocator = allocator
	building.entries = make(map[u32]string, allocator)
	defer if error != .None {
		destroy(&building)
	}

	remaining := strings.trim_prefix(content, "\xef\xbb\xbf")
	for line in strings.split_lines_iterator(&remaining) {
		if !strings.has_prefix(line, "STRING ") {
			continue
		}
		key := parse_key(line[len("STRING "):])
		skip_to_opening_brace(&remaining) or_return
		body := parse_body(&remaining, allocator) or_return
		if previous, exists := building.entries[key]; exists {
			delete(previous, allocator)
		}
		building.entries[key] = body
	}
	return building, .None
}

// Whitespace and leading zeros tolerated; unparsable keys become 0
// (mirrored from War3Net, which does the same rather than erroring).
@(private)
parse_key :: proc(text: string) -> u32 {
	trimmed := strings.trim_space(text)
	value, ok := strconv.parse_uint(trimmed, 10)
	if !ok || value > uint(max(u32)) {
		return 0
	}
	return u32(value)
}

// Consumes lines up to and including the opening "{". Comment lines
// are allowed in between: the first must start with "//", after which
// any non-brace line continues the comment (War3Net's rule).
@(private)
skip_to_opening_brace :: proc(remaining: ^string) -> Error {
	in_comment := false
	for line in strings.split_lines_iterator(remaining) {
		if line == "{" {
			return .None
		}
		if strings.has_prefix(line, "//") || in_comment {
			in_comment = true
			continue
		}
		return .Missing_Opening_Brace
	}
	return .Missing_Opening_Brace
}

// Consumes body lines up to the closing "}" and joins them with "\n".
@(private)
parse_body :: proc(remaining: ^string, allocator: runtime.Allocator) -> (body: string, error: Error) {
	builder := strings.builder_make(allocator)
	defer if error != .None {
		strings.builder_destroy(&builder)
	}
	first_line := true
	for line in strings.split_lines_iterator(remaining) {
		if line == "}" {
			return strings.to_string(builder), .None
		}
		if !first_line {
			strings.write_byte(&builder, '\n')
		}
		strings.write_string(&builder, line)
		first_line = false
	}
	return "", .Missing_Closing_Brace
}

// Returns the key of a "TRIGSTR_<n>" reference. The number tolerates
// surrounding whitespace and leading zeros (War3Net's TryGetValue
// uses the same lenient number parse).
reference_key :: proc(text: string) -> (key: u32, is_reference: bool) {
	if !strings.has_prefix(text, REFERENCE_PREFIX) {
		return 0, false
	}
	trimmed := strings.trim_space(text[len(REFERENCE_PREFIX):])
	value, ok := strconv.parse_uint(trimmed, 10)
	if !ok || value > uint(max(u32)) {
		return 0, false
	}
	return u32(value), true
}

lookup :: proc(trigger_strings: ^Trigger_Strings, key: u32) -> (value: string, found: bool) {
	return trigger_strings.entries[key]
}

// Returns the referenced table entry when text is a "TRIGSTR_<n>"
// reference with a table entry; otherwise returns text unchanged.
resolve :: proc(trigger_strings: ^Trigger_Strings, text: string) -> string {
	key, is_reference := reference_key(text)
	if !is_reference {
		return text
	}
	value, found := lookup(trigger_strings, key)
	if !found {
		return text
	}
	return value
}
