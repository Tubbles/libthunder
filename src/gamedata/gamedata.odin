package gamedata

// The gameplay database: Blizzard's SLK tables and profile TXT files
// assembled into typed per-object field lookups, with a map's object
// data (thunder:formats/object_data) applied on top.
//
// A record is addressed by object kind, rawcode and *modification id*
// (`uhpm`, `igol`, `Hbz1`, ...), the same four-character ids the object
// editor and every map's object-data file use. The nine metadata SLKs
// (Units\UnitMetaData.slk and siblings) are what makes that possible:
// each metadata row binds one modification id to one source table plus
// one column or TXT key, so the same key space covers the base tables,
// the profile TXT files and a map's overrides. Fields the metadata
// cannot reach (SLK bookkeeping columns like `sort`, editor-derived
// helpers like UnitWeapons' `DPS`) are deliberately not carried: no
// object-data file can address them, and none of them is gameplay
// state.
//
// This is a pure data layer. It stores what the files say and resolves
// lookups; it derives nothing.
//
// The corpus facts the design rests on (WI-0015 survey against patch
// 1.29.2, work/wi0015-metadata-survey.md):
//
// - Modification-id lookup is case sensitive. Eight ids collide when
//   lowercased (`Igol`/`igol`, `Ilev`/`ilev`, `Ilum`/`ilum`,
//   `Istr`/`istr`, `Ucs1`/`ucs1`, `Ucs2`/`ucs2`, `Udp1`/`udp1`,
//   `Udp2`/`udp2`), pairing an ability Data field with an item or unit
//   field, so folding case silently swaps an item's gold cost for an
//   ability's DataX. Member names and TXT keys, on the other hand, are
//   matched case insensitively (`Units\unitUI.slk`, metadata
//   `CasterArt` against TXT key `Casterart`).
// - `Crs` is the one three-character metadata id and arrives NUL
//   padded from the file, so ids are keyed as a right-zero-padded
//   [4]u8.
// - The metadata row, never the file extension, decides the target
//   table: (4)WarChasers.w3m has no war3map.w3t and keeps its item
//   modifications in war3map.w3u.
// - A leveled field's data pointer maps A=1 through I=9 with nothing
//   skipped (metadata `data`=5 is DataE; ability Afbt's DataE1 is 20,
//   the value its stock tooltip quotes).
// - Level suffixes come in two widths that are a per-table property,
//   not a fallback: AbilityData writes `DataA1`, Doodads.slk writes
//   `vertR01`.
// - Object data assigns levels past the base table's stored slots (up
//   to 15 against AbilityData's 4) and occasionally level 0 on a
//   leveled field, so levels grow on demand and are stored as written.
// - `-` and `_` are the SLK's "unset" spellings, sometimes padded with
//   spaces (` - `), and are dropped at the read boundary.

import "base:runtime"
import "core:strconv"
import "core:strings"

Error :: enum {
	None,
	Invalid_Metadata,
	Invalid_Table,
	Unknown_Table,
	Missing_Member,
	Invalid_Object_Data,
}

// The seven object families the base tables define. Their rawcode
// spaces are disjoint in the stock data (verified: zero shared keys
// between any two families), so a rawcode alone identifies the family
// an object-data entry belongs to.
Object_Kind :: enum {
	Unit,
	Item,
	Ability,
	Buff,
	Upgrade,
	Destructable,
	Doodad,
}

// A stored field value. Numbers come from the SLK cells and from an
// object-data modification's Integer/Real/Unreal tag; profile TXT
// values are always strings.
Value :: union {
	i64,
	f64,
	string,
}

// One field of one object. `unleveled` is what an unsuffixed SLK
// column, a whole TXT value, or a modification stating level 0 wrote;
// `levels[level - 1]` is the per-level value. A nil entry means the
// slot was never written.
Field :: struct {
	unleveled: Value,
	levels:    [dynamic]Value,
}

Object :: struct {
	id:      [4]u8,
	// The standard object this one derives from. Equal to `id` for
	// entries that come from the base tables and for object-data
	// modifications of a standard entry; the cloned original for a
	// custom entry.
	base_id: [4]u8,
	kind:    Object_Kind,
	fields:  map[[4]u8]Field,
}

// Counters over everything a load touched. They exist so the corpus
// sweep can assert that nothing silently fell out (an unresolved
// modification id or a dropped profile section is a regression signal,
// not a fatal error).
Load_Stats :: struct {
	metadata_files:             int,
	metadata_rows:              int,
	metadata_duplicate_ids:     int,
	metadata_unknown_tables:    int,
	// TXT keys that feed more than one field, `Buttonpos` style.
	profile_name_aliases:       int,
	table_values:               int,
	profile_values:             int,
	profile_sections_skipped:   int,
	profile_keys_unresolved:    int,
	modifications_applied:      int,
	modifications_unresolved:   int,
	// Modifications naming a level past MAXIMUM_LEVEL.
	modification_level_drops:   int,
	// Modifications whose data pointer disagrees with the metadata's
	// `data` column. Zero across the corpus.
	data_pointer_mismatches:    int,
	object_data_entries:        int,
	// Custom entries whose cloned original is in no table.
	object_data_custom_orphans: int,
}

Database :: struct {
	metadata:  Metadata,
	objects:   [Object_Kind]map[[4]u8]Object,
	stats:     Load_Stats,
	allocator: runtime.Allocator,
}

// Levels are file-supplied, so the slot count is capped before any
// allocation. The corpus tops out at 15 (custom 15-level abilities
// against AbilityData's 4 stored levels); the cap is far above that
// and a modification past it is dropped and counted rather than
// allowed to size an allocation.
MAXIMUM_LEVEL :: 512

make_database :: proc(allocator := context.allocator) -> (database: Database) {
	database.allocator = allocator
	database.metadata = make_metadata(allocator)
	for kind in Object_Kind {
		database.objects[kind] = make(map[[4]u8]Object, allocator)
	}
	return database
}

destroy :: proc(database: ^Database) {
	for kind in Object_Kind {
		for _, &object in database.objects[kind] {
			destroy_object(&object, database.allocator)
		}
		delete(database.objects[kind])
	}
	destroy_metadata(&database.metadata)
	database^ = {}
}

// Right-zero-pads a one to four character code, matching how a
// three-character metadata id (`Crs`) reaches us from a file's fixed
// four-byte id field.
rawcode :: proc(text: string) -> (id: [4]u8, ok: bool) {
	if len(text) == 0 || len(text) > 4 {
		return {}, false
	}
	copy(id[:], text)
	return id, true
}

find_object :: proc(database: ^Database, kind: Object_Kind, id: [4]u8) -> (object: ^Object, found: bool) {
	object = &database.objects[kind][id]
	return object, object != nil
}

// The family a rawcode belongs to. The stock families share no
// rawcodes, so at most one can match.
find_kind :: proc(database: ^Database, id: [4]u8) -> (kind: Object_Kind, found: bool) {
	for candidate in Object_Kind {
		if id in database.objects[candidate] {
			return candidate, true
		}
	}
	return .Unit, false
}

find_field :: proc(database: ^Database, kind: Object_Kind, id: [4]u8, field_id: [4]u8) -> (field: ^Field, found: bool) {
	object := find_object(database, kind, id) or_return
	field = &object.fields[field_id]
	return field, field != nil
}

// Resolves one field at one level. The policy, in order:
//
//  1. level < 0 misses.
//  2. The exact slot, if something was written there.
//  3. For level >= 1, the unleveled slot: a field written without a
//     level applies to every level.
//  4. For level 0, level 1: a leveled field asked without a level
//     answers with its first level.
//
// Nothing is clamped. Asking level 9 of a four-level field misses
// unless an unleveled value stands in, which keeps "the file never
// said" distinguishable from "the file said this".
find_value :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_id: [4]u8,
	level := 0,
) -> (
	value: Value,
	found: bool,
) {
	field := find_field(database, kind, id, field_id) or_return
	return field_value(field, level)
}

field_value :: proc(field: ^Field, level: int) -> (value: Value, found: bool) {
	if level < 0 {
		return nil, false
	}
	if level >= 1 && level <= len(field.levels) && field.levels[level - 1] != nil {
		return field.levels[level - 1], true
	}
	if field.unleveled != nil {
		return field.unleveled, true
	}
	if level == 0 && len(field.levels) > 0 && field.levels[0] != nil {
		return field.levels[0], true
	}
	return nil, false
}

find_integer :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_id: [4]u8,
	level := 0,
) -> (
	number: i64,
	found: bool,
) {
	value := find_value(database, kind, id, field_id, level) or_return
	return value_integer(value)
}

find_real :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_id: [4]u8,
	level := 0,
) -> (
	number: f64,
	found: bool,
) {
	value := find_value(database, kind, id, field_id, level) or_return
	return value_real(value)
}

// Text lookups answer only for stored strings. A numeric SLK cell is a
// number, not its spelling: formatting it back would invent a format
// the file never chose.
find_text :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_id: [4]u8,
	level := 0,
) -> (
	text: string,
	found: bool,
) {
	value := find_value(database, kind, id, field_id, level) or_return
	return value.(string)
}

// Convenience lookup by field name (the metadata `field`, plus the
// data letter for the `DataX` family, matched case insensitively).
// It searches the object's own fields, so it answers with the exact
// descriptor that object carries: several ids can name the same
// column, and which one applies is decided per object by the
// metadata's useSpecific/notSpecific lists. Two stock abilities (AIlb
// and AIpb, where Idic and Idam both declare DataA) do end up with
// two ids on one column, and for those the answer is whichever the
// field map yields first; address them by id to be exact.
find_value_by_name :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_name: string,
	level := 0,
) -> (
	value: Value,
	found: bool,
) {
	field_id := find_field_id_by_name(database, kind, id, field_name) or_return
	return find_value(database, kind, id, field_id, level)
}

find_field_id_by_name :: proc(
	database: ^Database,
	kind: Object_Kind,
	id: [4]u8,
	field_name: string,
) -> (
	field_id: [4]u8,
	found: bool,
) {
	object := find_object(database, kind, id) or_return
	for candidate in object.fields {
		descriptor, has_descriptor := find_descriptor(&database.metadata, candidate)
		if !has_descriptor {
			continue
		}
		if strings.equal_fold(descriptor.column, field_name) {
			return candidate, true
		}
	}
	return {}, false
}

value_integer :: proc(value: Value) -> (number: i64, ok: bool) {
	switch stored in value {
	case i64:
		return stored, true
	case f64:
		return i64(stored), true
	case string:
		return strconv.parse_i64(strings.trim_space(stored))
	}
	return 0, false
}

value_real :: proc(value: Value) -> (number: f64, ok: bool) {
	switch stored in value {
	case i64:
		return f64(stored), true
	case f64:
		return stored, true
	case string:
		return strconv.parse_f64(strings.trim_space(stored))
	}
	return 0, false
}

@(private)
ensure_object :: proc(database: ^Database, kind: Object_Kind, id: [4]u8) -> ^Object {
	existing := &database.objects[kind][id]
	if existing != nil {
		return existing
	}
	database.objects[kind][id] = Object {
		id      = id,
		base_id = id,
		kind    = kind,
		fields  = make(map[[4]u8]Field, database.allocator),
	}
	return &database.objects[kind][id]
}

@(private)
destroy_object :: proc(object: ^Object, allocator: runtime.Allocator) {
	for _, &field in object.fields {
		destroy_field(&field, allocator)
	}
	delete(object.fields)
	object^ = {}
}

@(private)
destroy_field :: proc(field: ^Field, allocator: runtime.Allocator) {
	delete_value(field.unleveled, allocator)
	for value in field.levels {
		delete_value(value, allocator)
	}
	delete(field.levels)
	field^ = {}
}

@(private)
delete_value :: proc(value: Value, allocator: runtime.Allocator) {
	if text, is_text := value.(string); is_text {
		delete(text, allocator)
	}
}

@(private)
clone_value :: proc(value: Value, allocator: runtime.Allocator) -> Value {
	if text, is_text := value.(string); is_text {
		return strings.clone(text, allocator)
	}
	return value
}

// Writes one slot, taking ownership of any string in `value` and
// freeing whatever it replaces. Levels past MAXIMUM_LEVEL are
// rejected so a file-supplied level cannot size an allocation.
@(private)
set_field_value :: proc(object: ^Object, field_id: [4]u8, level: int, value: Value, allocator: runtime.Allocator) -> bool {
	if level < 0 || level > MAXIMUM_LEVEL {
		delete_value(value, allocator)
		return false
	}
	if field_id not_in object.fields {
		object.fields[field_id] = Field{}
	}
	field := &object.fields[field_id]
	if level == 0 {
		delete_value(field.unleveled, allocator)
		field.unleveled = value
		return true
	}
	if field.levels == nil {
		field.levels = make([dynamic]Value, 0, level, allocator)
	}
	for len(field.levels) < level {
		append(&field.levels, nil)
	}
	delete_value(field.levels[level - 1], allocator)
	field.levels[level - 1] = value
	return true
}
