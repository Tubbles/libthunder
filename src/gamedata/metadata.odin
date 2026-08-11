package gamedata

// The nine metadata SLKs, which are the object editor's own field
// dictionary: one row per modification id, naming the table (or the
// profile TXT) the field lives in, its column or key, its type, and
// where levels and packed elements come from.
//
// The nine files hold 2300 rows in patch 1.29.2 and every ID is
// distinct across all of them, so one flat case-sensitive id map is
// enough; the file a row came from is kept on the descriptor because
// it decides which object family the field belongs to.

import "base:runtime"
import "core:strconv"
import "core:strings"
import slk "thunder:formats/slk"

Metadata_Source :: enum {
	Unit,
	Ability,
	Ability_Buff,
	Destructable,
	Upgrade,
	Upgrade_Effect,
	Misc,
	Doodad,
	Skin,
}

METADATA_MEMBERS :: [Metadata_Source]string {
	.Unit           = "Units\\UnitMetaData.slk",
	.Ability        = "Units\\AbilityMetaData.slk",
	.Ability_Buff   = "Units\\AbilityBuffMetaData.slk",
	.Destructable   = "Units\\DestructableMetaData.slk",
	.Upgrade        = "Units\\UpgradeMetaData.slk",
	.Upgrade_Effect = "Units\\UpgradeEffectMetaData.slk",
	.Misc           = "Units\\MiscMetaData.slk",
	.Doodad         = "Doodads\\DoodadMetaData.slk",
	.Skin           = "UI\\SkinMetaData.slk",
}

// The logical table names the metadata's `slk` column uses. They are
// not file names: `DoodadData` is Doodads\Doodads.slk, and `Profile`
// means the field lives in a TXT file instead of a table.
Table :: enum {
	None,
	Profile,
	Unit_Data,
	Unit_UI,
	Unit_Balance,
	Unit_Weapons,
	Unit_Abilities,
	Item_Data,
	Ability_Data,
	Ability_Buff_Data,
	Destructable_Data,
	Upgrade_Data,
	Doodad_Data,
}

TABLE_MEMBERS :: #partial [Table]string {
	.Unit_Data         = "Units\\UnitData.slk",
	.Unit_UI           = "Units\\UnitUI.slk",
	.Unit_Balance      = "Units\\UnitBalance.slk",
	.Unit_Weapons      = "Units\\UnitWeapons.slk",
	.Unit_Abilities    = "Units\\UnitAbilities.slk",
	.Item_Data         = "Units\\ItemData.slk",
	.Ability_Data      = "Units\\AbilityData.slk",
	.Ability_Buff_Data = "Units\\AbilityBuffData.slk",
	.Destructable_Data = "Units\\DestructableData.slk",
	.Upgrade_Data      = "Units\\UpgradeData.slk",
	.Doodad_Data       = "Doodads\\Doodads.slk",
}

// Each table's key column, all of them at column 0 in the stock files.
// UnitWeapons' is literally named `serpent`, and the table carries one
// row (`nrmf`) its four sibling unit tables lack, so the unit tables
// are joined by key and never by row position.
TABLE_KEY_COLUMNS :: #partial [Table]string {
	.Unit_Data         = "unitID",
	.Unit_UI           = "unitUIID",
	.Unit_Balance      = "unitBalanceID",
	.Unit_Weapons      = "serpent",
	.Unit_Abilities    = "unitAbilID",
	.Item_Data         = "itemID",
	.Ability_Data      = "alias",
	.Ability_Buff_Data = "alias",
	.Destructable_Data = "DestructableID",
	.Upgrade_Data      = "upgradeid",
	.Doodad_Data       = "doodID",
}

// How wide a level suffix is written in each table's column names, a
// per-table property rather than a fallback chain: AbilityData writes
// `DataA1`, Doodads.slk writes `vertR01`. Only those two tables carry
// leveled columns at all (metadata `repeat` > 0 with an SLK table
// names AbilityData or DoodadData and nothing else), so the width 1
// left on the others is never exercised.
TABLE_LEVEL_SUFFIX_WIDTHS :: [Table]int {
	.None              = 1,
	.Profile           = 1,
	.Unit_Data         = 1,
	.Unit_UI           = 1,
	.Unit_Balance      = 1,
	.Unit_Weapons      = 1,
	.Unit_Abilities    = 1,
	.Item_Data         = 1,
	.Ability_Data      = 1,
	.Ability_Buff_Data = 1,
	.Destructable_Data = 1,
	.Upgrade_Data      = 1,
	.Doodad_Data       = 2,
}

// How a value is stored once read. The mapping from the metadata's 70
// type names is exact against the corpus: over every corpus
// modification, the metadata type determines the object-data file's
// value tag with no ambiguity.
Storage_Class :: enum {
	Integer,
	Real,
	Unreal,
	String,
}

Field_Descriptor :: struct {
	id:              [4]u8,
	source:          Metadata_Source,
	table:           Table,
	// The metadata `field`: an SLK column name or a TXT key, before
	// any data letter or level suffix.
	field:           string,
	// `field` plus the data letter, so `Data` with data=5 is `DataE`.
	// This is the name a lookup by name matches against.
	column:          string,
	lowered_field:   string,
	type_name:       string,
	storage:         Storage_Class,
	// 0 for a plain field, 1..9 for DataA..DataI. Nothing is skipped:
	// data=5 is DataE (ability Afbt's DataE1 = 20).
	data:            int,
	// 0 for a single-valued field; otherwise the number of slots the
	// base table stores. It is not a level cap: object data assigns
	// levels well past it.
	repeat:          int,
	// -1 for "the whole value"; 0 or 1 to select an element of a
	// comma-separated value (`Buttonpos=0,0` feeds ubpx and ubpy).
	// Rows whose sibling rows never use an element index are whole
	// value even where the metadata writes 0.
	element_index:   int,
	// The per-level TXT key is the field name with the level appended
	// (`Requires1`, `Requires2`). Only two upgrade rows use it.
	append_index:    bool,
	use_item:        bool,
	use_unit:        bool,
	// Ability fields are declared for named abilities: useSpecific
	// lists the only objects a field belongs to, notSpecific excludes
	// objects from an otherwise generic field. Honoring both is what
	// keeps each ability to its own DataX rows instead of all 200.
	use_specific:    [][4]u8,
	not_specific:    [][4]u8,
	// The next descriptor in the same metadata file naming the same
	// field, or -1. One TXT key can feed several fields: `Buttonpos`
	// is both `ubpx` (element 0) and `ubpy` (element 1), and `Art` is
	// `uico` for a unit and `iico` for an item.
	next_same_field: int,
}

@(private)
Profile_Name_Key :: struct {
	kind: Object_Kind,
	name: string,
}

Metadata :: struct {
	descriptors:   [dynamic]Field_Descriptor,
	// Exact, case-sensitive, ids right-zero-padded to four bytes.
	by_id:         map[[4]u8]int,
	// Profile TXT key to descriptor, per object family, lowercased.
	profile_names: map[Profile_Name_Key]int,
	allocator:     runtime.Allocator,
}

make_metadata :: proc(allocator := context.allocator) -> (metadata: Metadata) {
	metadata.allocator = allocator
	metadata.descriptors = make([dynamic]Field_Descriptor, allocator)
	metadata.by_id = make(map[[4]u8]int, allocator)
	metadata.profile_names = make(map[Profile_Name_Key]int, allocator)
	return metadata
}

destroy_metadata :: proc(metadata: ^Metadata) {
	for descriptor in metadata.descriptors {
		delete(descriptor.field, metadata.allocator)
		delete(descriptor.column, metadata.allocator)
		delete(descriptor.lowered_field, metadata.allocator)
		delete(descriptor.type_name, metadata.allocator)
		delete(descriptor.use_specific, metadata.allocator)
		delete(descriptor.not_specific, metadata.allocator)
	}
	delete(metadata.descriptors)
	delete(metadata.by_id)
	delete(metadata.profile_names)
	metadata^ = {}
}

// Descriptor pointers stay valid as long as no further metadata file
// is added, which is the case for a database that finished loading.
find_descriptor :: proc(metadata: ^Metadata, id: [4]u8) -> (descriptor: ^Field_Descriptor, found: bool) {
	index := metadata.by_id[id] or_return
	return &metadata.descriptors[index], true
}

// Reads one metadata SLK. Rows are appended, so the nine files are
// added one after another into the same id space.
metadata_add :: proc(metadata: ^Metadata, source: Metadata_Source, content: string, stats: ^Load_Stats = nil) -> Error {
	table, parse_error := slk.parse(content, metadata.allocator)
	defer slk.destroy(&table)
	if parse_error != .None || table.row_count < 2 {
		return .Invalid_Metadata
	}

	columns := make_column_index(&table, metadata.allocator)
	defer destroy_column_index(&columns, metadata.allocator)
	id_column, has_id_column := columns["id"]
	if !has_id_column {
		return .Invalid_Metadata
	}
	field_column, has_field_column := columns["field"]
	table_column, has_table_column := columns["slk"]

	first_added := len(metadata.descriptors)
	for row in 1 ..< table.row_count {
		id_text := strings.trim_space(cell_string(&table, row, id_column))
		id, id_ok := rawcode(id_text)
		if !id_ok {
			continue
		}
		descriptor := Field_Descriptor {
			id              = id,
			source          = source,
			table           = .None,
			element_index   = -1,
			next_same_field = -1,
		}
		if has_field_column {
			descriptor.field = strings.clone(strings.trim_space(cell_string(&table, row, field_column)), metadata.allocator)
		} else {
			descriptor.field = strings.clone("", metadata.allocator)
		}
		if has_table_column {
			table_name := strings.trim_space(cell_string(&table, row, table_column))
			known: bool
			descriptor.table, known = table_from_name(table_name)
			if !known && len(table_name) > 0 && stats != nil {
				stats.metadata_unknown_tables += 1
			}
		}
		descriptor.data = column_integer(&table, &columns, row, "data", 0)
		descriptor.repeat = column_integer(&table, &columns, row, "repeat", 0)
		descriptor.element_index = column_integer(&table, &columns, row, "index", -1)
		descriptor.append_index = column_integer(&table, &columns, row, "appendindex", 0) == 1
		descriptor.use_item = column_integer(&table, &columns, row, "useitem", 0) == 1
		descriptor.use_unit =
			column_integer(&table, &columns, row, "useunit", 0) == 1 ||
			column_integer(&table, &columns, row, "usehero", 0) == 1 ||
			column_integer(&table, &columns, row, "usebuilding", 0) == 1
		descriptor.type_name = strings.clone(strings.trim_space(column_string(&table, &columns, row, "type")), metadata.allocator)
		descriptor.storage = storage_class_for_type(descriptor.type_name)
		descriptor.use_specific = parse_code_list(column_string(&table, &columns, row, "usespecific"), metadata.allocator)
		descriptor.not_specific = parse_code_list(column_string(&table, &columns, row, "notspecific"), metadata.allocator)
		descriptor.column = column_with_data_letter(descriptor.field, descriptor.data, metadata.allocator)
		descriptor.lowered_field = strings.to_lower(descriptor.field, metadata.allocator)

		append(&metadata.descriptors, descriptor)
		if stats != nil {
			stats.metadata_rows += 1
		}
		if id in metadata.by_id {
			if stats != nil {
				stats.metadata_duplicate_ids += 1
			}
			continue
		}
		metadata.by_id[id] = len(metadata.descriptors) - 1
	}

	resolve_element_indexes(metadata, first_added)
	register_profile_names(metadata, first_added, stats)
	if stats != nil {
		stats.metadata_files += 1
	}
	return .None
}

table_from_name :: proc(name: string) -> (table: Table, known: bool) {
	switch {
	case strings.equal_fold(name, "Profile"):
		return .Profile, true
	case strings.equal_fold(name, "UnitData"):
		return .Unit_Data, true
	case strings.equal_fold(name, "UnitUI"):
		return .Unit_UI, true
	case strings.equal_fold(name, "UnitBalance"):
		return .Unit_Balance, true
	case strings.equal_fold(name, "UnitWeapons"):
		return .Unit_Weapons, true
	case strings.equal_fold(name, "UnitAbilities"):
		return .Unit_Abilities, true
	case strings.equal_fold(name, "ItemData"):
		return .Item_Data, true
	case strings.equal_fold(name, "AbilityData"):
		return .Ability_Data, true
	case strings.equal_fold(name, "AbilityBuffData"):
		return .Ability_Buff_Data, true
	case strings.equal_fold(name, "DestructableData"):
		return .Destructable_Data, true
	case strings.equal_fold(name, "UpgradeData"):
		return .Upgrade_Data, true
	case strings.equal_fold(name, "DoodadData"):
		return .Doodad_Data, true
	}
	return .None, false
}

// The object family a table defines. Profile fields have no family of
// their own: which one they belong to follows from the object the TXT
// section names.
kind_for_table :: proc(table: Table) -> (kind: Object_Kind, known: bool) {
	#partial switch table {
	case .Unit_Data, .Unit_UI, .Unit_Balance, .Unit_Weapons, .Unit_Abilities:
		return .Unit, true
	case .Item_Data:
		return .Item, true
	case .Ability_Data:
		return .Ability, true
	case .Ability_Buff_Data:
		return .Buff, true
	case .Destructable_Data:
		return .Destructable, true
	case .Upgrade_Data:
		return .Upgrade, true
	case .Doodad_Data:
		return .Doodad, true
	}
	return .Unit, false
}

// Which families a descriptor can apply to. Only UnitMetaData mixes
// two (units and items share one metadata file), and its use flags
// separate them: `Art` is `uico` for a unit and `iico` for an item.
descriptor_applies_to_kind :: proc(descriptor: ^Field_Descriptor, kind: Object_Kind) -> bool {
	#partial switch descriptor.source {
	case .Unit:
		if kind == .Item {
			return descriptor.use_item
		}
		return kind == .Unit && descriptor.use_unit
	case .Ability:
		return kind == .Ability
	case .Ability_Buff:
		return kind == .Buff
	case .Destructable:
		return kind == .Destructable
	case .Upgrade:
		return kind == .Upgrade
	case .Doodad:
		return kind == .Doodad
	}
	return false
}

// Whether a field belongs to one specific object, per the metadata's
// useSpecific and notSpecific lists.
descriptor_applies_to_object :: proc(descriptor: ^Field_Descriptor, id: [4]u8) -> bool {
	if len(descriptor.use_specific) > 0 {
		for code in descriptor.use_specific {
			if code == id {
				return true
			}
		}
		return false
	}
	for code in descriptor.not_specific {
		if code == id {
			return false
		}
	}
	return true
}

storage_class_for_type :: proc(type_name: string) -> Storage_Class {
	switch {
	case strings.equal_fold(type_name, "real"):
		return .Real
	case strings.equal_fold(type_name, "unreal"):
		return .Unreal
	case strings.equal_fold(type_name, "int"),
	     strings.equal_fold(type_name, "bool"),
	     strings.equal_fold(type_name, "attackBits"),
	     strings.equal_fold(type_name, "channelFlags"),
	     strings.equal_fold(type_name, "channelType"),
	     strings.equal_fold(type_name, "deathType"),
	     strings.equal_fold(type_name, "detectionType"),
	     strings.equal_fold(type_name, "fullFlags"),
	     strings.equal_fold(type_name, "spellDetail"),
	     strings.equal_fold(type_name, "stackFlags"),
	     strings.equal_fold(type_name, "teamColor"),
	     strings.equal_fold(type_name, "versionFlags"):
		return .Integer
	}
	return .String
}

// The SLK column a descriptor reads at a given level. Level 0 is the
// bare column; a level appends the digits in the table's suffix width.
column_name_for_level :: proc(descriptor: ^Field_Descriptor, level: int, allocator := context.allocator) -> string {
	if level <= 0 {
		return strings.clone(descriptor.column, allocator)
	}
	widths := TABLE_LEVEL_SUFFIX_WIDTHS
	width := widths[descriptor.table]
	digits: [8]u8
	text := strconv.write_int(digits[:], i64(level), 10)
	builder := strings.builder_make(allocator)
	strings.write_string(&builder, descriptor.column)
	for _ in len(text) ..< width {
		strings.write_byte(&builder, '0')
	}
	strings.write_string(&builder, text)
	return strings.to_string(builder)
}

@(private)
column_with_data_letter :: proc(field: string, data: int, allocator: runtime.Allocator) -> string {
	if data < 1 || data > 9 {
		return strings.clone(field, allocator)
	}
	builder := strings.builder_make(allocator)
	strings.write_string(&builder, field)
	strings.write_byte(&builder, 'A' + u8(data - 1))
	return strings.to_string(builder)
}

// The metadata writes `index` as 0 on rows whose value is scalar as
// well as on rows that really do take element 0 of a packed value.
// The rows that pack are exactly those with a sibling row on the same
// field using index 1 or higher, so a group without one is whole
// value throughout.
@(private)
resolve_element_indexes :: proc(metadata: ^Metadata, first_added: int) {
	Group_Key :: struct {
		table: Table,
		name:  string,
	}
	packed := make(map[Group_Key]bool, metadata.allocator)
	defer delete(packed)
	for index in first_added ..< len(metadata.descriptors) {
		descriptor := &metadata.descriptors[index]
		if descriptor.element_index >= 1 {
			packed[{descriptor.table, descriptor.lowered_field}] = true
		}
	}
	for index in first_added ..< len(metadata.descriptors) {
		descriptor := &metadata.descriptors[index]
		if descriptor.element_index >= 0 && !packed[{descriptor.table, descriptor.lowered_field}] {
			descriptor.element_index = -1
		}
	}
}

// Indexes the file's profile fields by TXT key, per object family, and
// chains the rows that share a key so a lookup reaches all of them.
// The registered head is the first row applying to that family, and
// the chain runs in file order, so every applicable row is reachable
// from its family's head.
@(private)
register_profile_names :: proc(metadata: ^Metadata, first_added: int, stats: ^Load_Stats) {
	last_by_name := make(map[string]int, metadata.allocator)
	defer delete(last_by_name)
	for index in first_added ..< len(metadata.descriptors) {
		descriptor := &metadata.descriptors[index]
		if descriptor.table != .Profile || len(descriptor.lowered_field) == 0 {
			continue
		}
		if previous, chained := last_by_name[descriptor.lowered_field]; chained {
			metadata.descriptors[previous].next_same_field = index
			if stats != nil {
				stats.profile_name_aliases += 1
			}
		}
		last_by_name[descriptor.lowered_field] = index
		for kind in Object_Kind {
			if !descriptor_applies_to_kind(descriptor, kind) {
				continue
			}
			key := Profile_Name_Key {
				kind = kind,
				name = descriptor.lowered_field,
			}
			if key in metadata.profile_names {
				continue
			}
			metadata.profile_names[key] = index
		}
	}
}

@(private)
parse_code_list :: proc(text: string, allocator: runtime.Allocator) -> [][4]u8 {
	trimmed := strings.trim_space(text)
	if len(trimmed) == 0 {
		return nil
	}
	count := 1
	for character in trimmed {
		if character == ',' {
			count += 1
		}
	}
	codes := make([dynamic][4]u8, 0, count, allocator)
	remaining := trimmed
	for {
		separator := strings.index_byte(remaining, ',')
		piece := remaining
		if separator >= 0 {
			piece = remaining[:separator]
		}
		if code, ok := rawcode(strings.trim_space(piece)); ok {
			append(&codes, code)
		}
		if separator < 0 {
			break
		}
		remaining = remaining[separator + 1:]
	}
	return codes[:]
}
