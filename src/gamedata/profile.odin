package gamedata

// The Profile pseudo-table: the TXT files under Units\ that carry the
// fields no SLK column holds (names, tooltips, icons, button
// positions, requirements). 1219 of the 2245 object-relevant metadata
// rows point at Profile.
//
// Their value grammar is quoted CSV, and both halves of it matter:
// quotes protect the commas inside 1145 stock values, and the commas
// separate either the elements of a packed value (`Buttonpos=0,0`
// feeding ubpx and ubpy) or one string per ability level
// (`Ubertip="level 1 text","level 2 text","level 3 text"`). Which of
// the two a value is comes from the field's metadata row, never from
// the value itself. Whitespace inside and around an element is part of
// the value: `EditorSuffix= (Spell Breaker)` leads with a space on
// purpose, which is why the profile reader parses with
// ini.Options{preserve_value_whitespace = true}.

import "core:strings"
import ini "thunder:formats/ini"

// Reads one profile TXT into the database, after the base tables:
// sections name objects by rawcode, and the family a rawcode belongs
// to is what the tables declare. A section is skipped when no base
// table declares that rawcode, because the family a profile-only
// section belongs to is not knowable. The stock files carry 836 such
// entries: buff and ability codes the SLK tables omit, plus [Misc],
// [HERO], [TWN1] and the command sections, which belong to
// MiscMetaData's separate section-keyed domain.
load_profile :: proc(database: ^Database, content: string) -> Error {
	file := ini.parse(content, database.allocator, ini.Options{preserve_value_whitespace = true})
	defer ini.destroy(&file)

	for &section in file.sections {
		id, id_ok := rawcode(strings.trim_space(section.name))
		if !id_ok {
			database.stats.profile_sections_skipped += 1
			continue
		}
		kind, kind_found := find_kind(database, id)
		if !kind_found {
			database.stats.profile_sections_skipped += 1
			continue
		}
		for entry in section.entries {
			apply_profile_entry(database, kind, id, entry.key, entry.value)
		}
	}
	return .None
}

@(private)
apply_profile_entry :: proc(database: ^Database, kind: Object_Kind, id: [4]u8, key: string, value: string) {
	lowered := strings.to_lower(strings.trim_space(key), database.allocator)
	defer delete(lowered, database.allocator)

	descriptor_index, found := database.metadata.profile_names[{kind, lowered}]
	appended_level := 0
	if !found {
		// The two upgrade rows with appendIndex spell their per-level
		// keys by appending the level (`Requires1`, `Requires2`). The
		// unit tables express the same tiering with distinct
		// modification ids instead, and those resolve above.
		base, number, has_digits := split_trailing_digits(lowered)
		if has_digits {
			candidate, candidate_found := database.metadata.profile_names[{kind, base}]
			if candidate_found && database.metadata.descriptors[candidate].append_index {
				descriptor_index = candidate
				found = true
				appended_level = number
			}
		}
	}
	if !found {
		database.stats.profile_keys_unresolved += 1
		return
	}

	object := ensure_object(database, kind, id)
	// One key can feed several fields: `Buttonpos=0,0` fills ubpx from
	// element 0 and ubpy from element 1.
	for index := descriptor_index; index >= 0; index = database.metadata.descriptors[index].next_same_field {
		descriptor := &database.metadata.descriptors[index]
		if !descriptor_applies_to_kind(descriptor, kind) {
			continue
		}
		store_profile_field(database, object, descriptor, value, appended_level)
	}
}

@(private)
store_profile_field :: proc(
	database: ^Database,
	object: ^Object,
	descriptor: ^Field_Descriptor,
	value: string,
	appended_level: int,
) {
	switch {
	case appended_level > 0:
		store_profile_value(database, object, descriptor.id, appended_level, profile_unquote(value))
	case descriptor.repeat > 0:
		cursor := 0
		level := 1
		for level <= MAXIMUM_LEVEL {
			element, has_element := next_profile_element(value, &cursor)
			if !has_element {
				break
			}
			store_profile_value(database, object, descriptor.id, level, element)
			level += 1
		}
	case descriptor.element_index >= 0:
		element, has_element := profile_element(value, descriptor.element_index)
		if !has_element {
			return
		}
		store_profile_value(database, object, descriptor.id, 0, element)
	case:
		store_profile_value(database, object, descriptor.id, 0, profile_unquote(value))
	}
}

@(private)
store_profile_value :: proc(database: ^Database, object: ^Object, field_id: [4]u8, level: int, text: string) {
	value := strings.clone(text, database.allocator)
	if set_field_value(object, field_id, level, value, database.allocator) {
		database.stats.profile_values += 1
	}
}

// The element at `index` of a quoted CSV value, as a slice of the
// input with one layer of surrounding quotes removed.
profile_element :: proc(value: string, index: int) -> (element: string, found: bool) {
	cursor := 0
	for position := 0; position <= index; position += 1 {
		element = next_profile_element(value, &cursor) or_return
	}
	return element, true
}

profile_element_count :: proc(value: string) -> (count: int) {
	cursor := 0
	for {
		_, has_element := next_profile_element(value, &cursor)
		if !has_element {
			return count
		}
		count += 1
	}
}

// Strips one layer of surrounding double quotes. Everything inside,
// commas and whitespace included, is kept verbatim.
profile_unquote :: proc(value: string) -> string {
	if len(value) >= 2 && value[0] == '"' && value[len(value) - 1] == '"' {
		return value[1:len(value) - 1]
	}
	return value
}

// Walks a quoted CSV value one element at a time. Commas inside
// double quotes are content, not separators. An empty input is one
// empty element, matching how the stock files write an unset key
// (`Missileart=`).
@(private)
next_profile_element :: proc(value: string, cursor: ^int) -> (element: string, ok: bool) {
	if cursor^ > len(value) {
		return "", false
	}
	start := cursor^
	inside_quotes := false
	position := start
	for position < len(value) {
		character := value[position]
		if character == '"' {
			inside_quotes = !inside_quotes
		} else if character == ',' && !inside_quotes {
			break
		}
		position += 1
	}
	cursor^ = position + 1
	return profile_unquote(value[start:position]), true
}

@(private)
split_trailing_digits :: proc(text: string) -> (base: string, number: int, has_digits: bool) {
	end := len(text)
	for end > 0 && text[end - 1] >= '0' && text[end - 1] <= '9' {
		end -= 1
	}
	if end == len(text) || end == 0 {
		return text, 0, false
	}
	for character in text[end:] {
		number = number * 10 + int(character - '0')
		if number > MAXIMUM_LEVEL {
			return text, 0, false
		}
	}
	return text[:end], number, true
}
