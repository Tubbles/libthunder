package gamedata

// Applying a map's object data on top of the base tables. The layering
// is base tables, then the file's original table (modifications to
// standard entries), then its custom table (new objects that clone a
// standard entry and then modify the copy), which is the order the
// files themselves are laid out in.
//
// The target family is decided per entry, not per file: (4)WarChasers
// .w3m is a RoC-era map with no war3map.w3t at all and keeps its item
// modifications in war3map.w3u, on entries whose old ids are item
// rawcodes. So the entry's own rawcode decides first, the metadata row
// of its modifications decides next, and the file extension is only
// the last resort.

import "base:runtime"
import "core:strings"
import object_data "thunder:formats/object_data"

// The object-data member extension to the family its entries default
// to when nothing better identifies them.
kind_for_extension :: proc(extension: string) -> (kind: Object_Kind, known: bool) {
	switch extension {
	case "w3u":
		return .Unit, true
	case "w3t":
		return .Item, true
	case "w3a":
		return .Ability, true
	case "w3h":
		return .Buff, true
	case "w3b":
		return .Destructable, true
	case "w3d":
		return .Doodad, true
	case "w3q":
		return .Upgrade, true
	}
	return .Unit, false
}

apply_object_data :: proc(database: ^Database, data: ^object_data.Object_Data, default_kind: Object_Kind) -> Error {
	for &entry in data.original {
		apply_original_entry(database, &entry, default_kind)
	}
	for &entry in data.custom {
		apply_custom_entry(database, &entry, default_kind)
	}
	return .None
}

@(private)
apply_original_entry :: proc(database: ^Database, entry: ^object_data.Entry, default_kind: Object_Kind) {
	kind := classify_entry(database, entry, default_kind)
	object := ensure_object(database, kind, entry.old_id)
	apply_modifications(database, object, entry.modifications)
	database.stats.object_data_entries += 1
}

// A custom entry defines a new object as a copy of a standard one with
// modifications on top. An entry that names no new id is a
// modification of the standard object instead.
@(private)
apply_custom_entry :: proc(database: ^Database, entry: ^object_data.Entry, default_kind: Object_Kind) {
	if entry.new_id == ([4]u8{}) {
		apply_original_entry(database, entry, default_kind)
		return
	}
	kind := classify_entry(database, entry, default_kind)
	if existing, exists := find_object(database, kind, entry.new_id); exists {
		destroy_object(existing, database.allocator)
		delete_key(&database.objects[kind], entry.new_id)
	}
	// The new object is inserted before the base is looked up: an
	// insertion can rehash the family's map, which would leave a base
	// pointer taken earlier dangling.
	object := ensure_object(database, kind, entry.new_id)
	object.base_id = entry.old_id
	base, has_base := find_object(database, kind, entry.old_id)
	if !has_base {
		database.stats.object_data_custom_orphans += 1
	} else if base != object {
		clone_fields(object, base, database.allocator)
	}
	apply_modifications(database, object, entry.modifications)
	database.stats.object_data_entries += 1
}

// Which family an entry belongs to: the base tables answer for every
// standard rawcode and for custom objects a later entry derives from,
// the modifications' metadata rows answer for an entry whose old id is
// unknown, and the file's extension is the fallback.
//
// The family the extension names is tried first, so that a custom
// rawcode a map happens to use in two of its object-data files stays
// with the file being read; the stock families share no rawcodes, so
// this only ever decides between custom entries.
@(private)
classify_entry :: proc(database: ^Database, entry: ^object_data.Entry, default_kind: Object_Kind) -> Object_Kind {
	if entry.old_id in database.objects[default_kind] {
		return default_kind
	}
	if kind, found := find_kind(database, entry.old_id); found {
		return kind
	}
	for modification in entry.modifications {
		descriptor, has_descriptor := find_descriptor(&database.metadata, modification.id)
		if !has_descriptor {
			continue
		}
		if kind, known := kind_for_table(descriptor.table); known {
			return kind
		}
	}
	return default_kind
}

@(private)
apply_modifications :: proc(database: ^Database, object: ^Object, modifications: []object_data.Modification) {
	for modification in modifications {
		descriptor, has_descriptor := find_descriptor(&database.metadata, modification.id)
		if !has_descriptor {
			// Stored anyway: the field key is the modification id, so
			// an id this build's metadata does not know still reaches
			// whoever does know it. The stock corpus resolves all 645.
			database.stats.modifications_unresolved += 1
		} else if descriptor.data != int(modification.data_pointer) {
			// The file's data pointer is redundant with the metadata's
			// `data` column and agrees with it on every corpus
			// modification, so a mismatch is worth counting.
			database.stats.data_pointer_mismatches += 1
		}
		value := modification_value(modification, database.allocator)
		if !set_field_value(object, modification.id, int(modification.level), value, database.allocator) {
			database.stats.modification_level_drops += 1
			continue
		}
		database.stats.modifications_applied += 1
	}
}

@(private)
modification_value :: proc(modification: object_data.Modification, allocator: runtime.Allocator) -> Value {
	switch stored in modification.value {
	case i32:
		return i64(stored)
	case f32:
		return f64(stored)
	case string:
		return strings.clone(stored, allocator)
	}
	return nil
}

@(private)
clone_fields :: proc(destination: ^Object, source: ^Object, allocator: runtime.Allocator) {
	for field_id, &field in source.fields {
		copy := Field {
			unleveled = clone_value(field.unleveled, allocator),
		}
		if len(field.levels) > 0 {
			copy.levels = make([dynamic]Value, len(field.levels), allocator)
			for value, index in field.levels {
				copy.levels[index] = clone_value(value, allocator)
			}
		}
		destination.fields[field_id] = copy
	}
}
