package doo

// Bounds-checked little-endian reading plus the two version-gated
// parses. Validation arithmetic on file-supplied counts runs in i64,
// before any allocation, so a 32-bit int target cannot wrap a product
// into a passing check (same approach as thunder:formats/w3i).

import "base:runtime"

@(private)
Reader :: struct {
	data:   []u8,
	offset: int,
}

@(private)
reader_remaining :: proc(reader: ^Reader) -> int {
	return len(reader.data) - reader.offset
}

@(private)
read_u32 :: proc(reader: ^Reader) -> (value: u32, ok: bool) {
	if reader_remaining(reader) < 4 {
		return 0, false
	}
	data := reader.data[reader.offset:]
	value = u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16 | u32(data[3]) << 24
	reader.offset += 4
	return value, true
}

@(private)
read_i32 :: proc(reader: ^Reader) -> (value: i32, ok: bool) {
	raw := read_u32(reader) or_return
	return i32(raw), true
}

@(private)
read_f32 :: proc(reader: ^Reader) -> (value: f32, ok: bool) {
	raw := read_u32(reader) or_return
	return transmute(f32)raw, true
}

// Reads the signed 24-bit level of a mode 0 random block.
@(private)
read_i24 :: proc(reader: ^Reader) -> (value: i32, ok: bool) {
	if reader_remaining(reader) < 3 {
		return 0, false
	}
	data := reader.data[reader.offset:]
	unsigned := u32(data[0]) | u32(data[1]) << 8 | u32(data[2]) << 16
	reader.offset += 3
	if unsigned >= 1 << 23 {
		return i32(unsigned) - (1 << 24), true
	}
	return i32(unsigned), true
}

@(private)
read_u8 :: proc(reader: ^Reader) -> (value: u8, ok: bool) {
	if reader_remaining(reader) < 1 {
		return 0, false
	}
	value = reader.data[reader.offset]
	reader.offset += 1
	return value, true
}

@(private)
read_bytes :: proc(reader: ^Reader, buffer: []u8) -> bool {
	if reader_remaining(reader) < len(buffer) {
		return false
	}
	copy(buffer, reader.data[reader.offset:])
	reader.offset += len(buffer)
	return true
}

@(private)
read_vector3 :: proc(reader: ^Reader) -> (value: [3]f32, ok: bool) {
	for &component in value {
		component = read_f32(reader) or_return
	}
	return value, true
}

// Reads a list count and validates it against the remaining bytes at
// the given minimum bytes per element, before the caller allocates.
// The element size is i64 so callers can pass version-dependent sizes
// without the expression itself being able to wrap on a 32-bit int
// target.
@(private)
read_count :: proc(reader: ^Reader, minimum_element_size: i64) -> (count: int, error: Error) {
	raw, ok := read_u32(reader)
	if !ok {
		return 0, .Truncated
	}
	if i64(raw) * minimum_element_size > i64(reader_remaining(reader)) {
		return 0, .Invalid_Count
	}
	return int(raw), .None
}

// Minimum bytes an entry of each kind occupies, used to reject counts
// that cannot fit before any allocation happens. Each is the fixed
// part of the entry with every counted list empty.
@(private)
UNIT_MINIMUM_SIZE_REIGN_OF_CHAOS :: 91
@(private)
UNIT_MINIMUM_SIZE_FROZEN_THRONE :: 107 // adds the item table id and the three hero stats
@(private)
DOODAD_MINIMUM_SIZE_REIGN_OF_CHAOS :: 42
@(private)
DOODAD_MINIMUM_SIZE_FROZEN_THRONE :: 50 // adds the item table id and the drop set count
@(private)
SPECIAL_DOODAD_SIZE :: 16
@(private)
DROPPED_ITEM_SIZE :: 8
@(private)
INVENTORY_ITEM_SIZE :: 8
@(private)
MODIFIED_ABILITY_SIZE :: 12
@(private)
RANDOM_UNIT_CHOICE_SIZE :: 8

// Reads the magic and the version pair shared by both files.
@(private)
parse_header :: proc(reader: ^Reader) -> (version: i32, sub_version: i32, error: Error) {
	magic: [4]u8
	if !read_bytes(reader, magic[:]) {
		return 0, 0, .Truncated
	}
	if string(magic[:]) != MAGIC {
		return 0, 0, .Bad_Magic
	}
	raw_version, version_ok := read_i32(reader)
	raw_sub_version, sub_version_ok := read_i32(reader)
	if !version_ok || !sub_version_ok {
		return 0, 0, .Truncated
	}
	// Only the two corpus pairs are accepted. War3Net additionally
	// knows v6 (Reign of Chaos beta) and sub-versions 7 and 10, none of
	// which occur in any stock map, and each of which moves fields
	// around; guessing at them would risk a silent mis-parse.
	is_reign_of_chaos :=
		raw_version == VERSION_REIGN_OF_CHAOS && raw_sub_version == SUB_VERSION_REIGN_OF_CHAOS
	is_frozen_throne :=
		raw_version == VERSION_FROZEN_THRONE && raw_sub_version == SUB_VERSION_FROZEN_THRONE
	if !is_reign_of_chaos && !is_frozen_throne {
		return 0, 0, .Unsupported_Version
	}
	return raw_version, raw_sub_version, .None
}

// Parses a complete war3mapUnits.doo file. On error the partially
// built value is freed and a zero value is returned.
parse_units :: proc(data: []u8, allocator := context.allocator) -> (placed: Placed_Units, error: Error) {
	building: Placed_Units
	building.allocator = allocator
	defer if error != .None {
		destroy_units(&building)
	}

	reader := Reader {
		data = data,
	}
	version, sub_version := parse_header(&reader) or_return
	building.version = version
	building.sub_version = sub_version

	minimum_size: i64 =
		version == VERSION_FROZEN_THRONE ? UNIT_MINIMUM_SIZE_FROZEN_THRONE : UNIT_MINIMUM_SIZE_REIGN_OF_CHAOS
	count := read_count(&reader, minimum_size) or_return
	building.units = make([]Placed_Unit, count, allocator)
	for &unit in building.units {
		parse_unit(&reader, &unit, version, allocator) or_return
	}
	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Bytes
	}
	return building, .None
}

@(private)
parse_unit :: proc(
	reader: ^Reader,
	unit: ^Placed_Unit,
	version: i32,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	if !read_bytes(reader, unit.type_id[:]) {
		return .Truncated
	}
	variation, variation_ok := read_i32(reader)
	position, position_ok := read_vector3(reader)
	rotation, rotation_ok := read_f32(reader)
	scale, scale_ok := read_vector3(reader)
	if !variation_ok || !position_ok || !rotation_ok || !scale_ok {
		return .Truncated
	}
	unit.variation = variation
	unit.position = position
	unit.rotation = rotation
	unit.scale = scale

	// The seven bytes after the scale are where the references
	// disagree: War3Net reads a flags byte, an int32 owning player and
	// two unknown bytes, while the HiveWE wiki reads a flags byte, an
	// int16 player number and an int32 flags field. Both consume seven
	// bytes. The corpus cannot separate them: across all 30323 placed
	// units the upper two bytes of War3Net's player field and both of
	// its unknown bytes are zero, so the two readings produce the same
	// player number everywhere. War3Net's is used, and the two bytes
	// are kept verbatim so nothing is lost either way.
	flags, flags_ok := read_u8(reader)
	owning_player, owning_player_ok := read_i32(reader)
	unknown_byte_1, unknown_1_ok := read_u8(reader)
	unknown_byte_2, unknown_2_ok := read_u8(reader)
	hit_points, hit_points_ok := read_i32(reader)
	mana_points, mana_points_ok := read_i32(reader)
	if !flags_ok || !owning_player_ok || !unknown_1_ok || !unknown_2_ok {
		return .Truncated
	}
	if !hit_points_ok || !mana_points_ok {
		return .Truncated
	}
	unit.flags = flags
	unit.owning_player = owning_player
	unit.unknown_byte_1 = unknown_byte_1
	unit.unknown_byte_2 = unknown_byte_2
	unit.hit_points = hit_points
	unit.mana_points = mana_points

	unit.item_table_id = NO_ITEM_TABLE
	if version == VERSION_FROZEN_THRONE {
		item_table_id, item_table_ok := read_i32(reader)
		if !item_table_ok {
			return .Truncated
		}
		unit.item_table_id = item_table_id
	}
	parse_item_sets(reader, &unit.dropped_item_sets, allocator) or_return

	gold_amount, gold_ok := read_i32(reader)
	target_acquisition, target_ok := read_f32(reader)
	hero_level, hero_level_ok := read_i32(reader)
	if !gold_ok || !target_ok || !hero_level_ok {
		return .Truncated
	}
	unit.gold_amount = gold_amount
	unit.target_acquisition = target_acquisition
	unit.hero_level = hero_level

	if version == VERSION_FROZEN_THRONE {
		// Zero in every corpus entry (no stock map overrides hero
		// stats), so only the twelve bytes themselves are corpus
		// confirmed, by the entries tiling to exact end of file; the
		// field identities come from the references.
		strength, strength_ok := read_i32(reader)
		agility, agility_ok := read_i32(reader)
		intelligence, intelligence_ok := read_i32(reader)
		if !strength_ok || !agility_ok || !intelligence_ok {
			return .Truncated
		}
		unit.hero_strength = strength
		unit.hero_agility = agility
		unit.hero_intelligence = intelligence
	}

	inventory_count := read_count(reader, INVENTORY_ITEM_SIZE) or_return
	unit.inventory = make([]Inventory_Item, inventory_count, allocator)
	for &item in unit.inventory {
		slot, slot_ok := read_i32(reader)
		if !slot_ok || !read_bytes(reader, item.id[:]) {
			return .Truncated
		}
		item.slot = slot
	}

	ability_count := read_count(reader, MODIFIED_ABILITY_SIZE) or_return
	unit.modified_abilities = make([]Modified_Ability, ability_count, allocator)
	for &ability in unit.modified_abilities {
		if !read_bytes(reader, ability.id[:]) {
			return .Truncated
		}
		autocast_active, autocast_ok := read_i32(reader)
		level, level_ok := read_i32(reader)
		if !autocast_ok || !level_ok {
			return .Truncated
		}
		ability.autocast_active = autocast_active
		ability.level = level
	}

	parse_random_unit(reader, unit, allocator) or_return

	custom_color, custom_color_ok := read_i32(reader)
	waygate_destination, waygate_ok := read_i32(reader)
	creation_number, creation_ok := read_i32(reader)
	if !custom_color_ok || !waygate_ok || !creation_ok {
		return .Truncated
	}
	unit.custom_color = custom_color
	unit.waygate_destination = waygate_destination
	unit.creation_number = creation_number
	return .None
}

// The random-unit block: a mode integer followed by one of three
// payload shapes. Modes other than 0, 1 and 2 carry no payload at all
// (War3Net's reader falls through to a null payload). The corpus needs
// that: 2367 entries store -1, and ten entries in (4)Roundabout.w3x
// store 641, all of them followed directly by the custom color. Both
// values are kept verbatim in random_mode.
@(private)
parse_random_unit :: proc(reader: ^Reader, unit: ^Placed_Unit, allocator: runtime.Allocator) -> (error: Error) {
	mode, mode_ok := read_i32(reader)
	if !mode_ok {
		return .Truncated
	}
	unit.random_mode = mode
	switch mode {
	case RANDOM_MODE_ANY:
		level, level_ok := read_i24(reader)
		item_class, item_class_ok := read_u8(reader)
		if !level_ok || !item_class_ok {
			return .Truncated
		}
		unit.random_data = Random_Any {
			level      = level,
			item_class = item_class,
		}
	case RANDOM_MODE_GLOBAL_TABLE:
		table_id, table_ok := read_i32(reader)
		column, column_ok := read_i32(reader)
		if !table_ok || !column_ok {
			return .Truncated
		}
		unit.random_data = Random_Global_Table {
			table_id = table_id,
			column   = column,
		}
	case RANDOM_MODE_CUSTOM_TABLE:
		choice_count := read_count(reader, RANDOM_UNIT_CHOICE_SIZE) or_return
		table := Random_Custom_Table {
			choices = make([]Random_Unit_Choice, choice_count, allocator),
		}
		unit.random_data = table
		for &choice in table.choices {
			if !read_bytes(reader, choice.id[:]) {
				return .Truncated
			}
			chance, chance_ok := read_i32(reader)
			if !chance_ok {
				return .Truncated
			}
			choice.chance = chance
		}
	}
	return .None
}

// The drop-table block shared by units and (in v8) destructables: a
// count of sets, each a count of weighted items. The destination is
// written before anything can fail so a partial parse still frees.
@(private)
parse_item_sets :: proc(
	reader: ^Reader,
	destination: ^[]Dropped_Item_Set,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	// Each set is at least its own item count.
	set_count := read_count(reader, 4) or_return
	destination^ = make([]Dropped_Item_Set, set_count, allocator)
	for &item_set in destination^ {
		item_count := read_count(reader, DROPPED_ITEM_SIZE) or_return
		item_set.items = make([]Dropped_Item, item_count, allocator)
		for &item in item_set.items {
			if !read_bytes(reader, item.id[:]) {
				return .Truncated
			}
			chance, chance_ok := read_i32(reader)
			if !chance_ok {
				return .Truncated
			}
			item.chance = chance
		}
	}
	return .None
}

// Parses a complete war3map.doo file. On error the partially built
// value is freed and a zero value is returned.
parse_doodads :: proc(data: []u8, allocator := context.allocator) -> (placed: Placed_Doodads, error: Error) {
	building: Placed_Doodads
	building.allocator = allocator
	defer if error != .None {
		destroy_doodads(&building)
	}

	reader := Reader {
		data = data,
	}
	version, sub_version := parse_header(&reader) or_return
	building.version = version
	building.sub_version = sub_version

	minimum_size: i64 =
		version == VERSION_FROZEN_THRONE ? DOODAD_MINIMUM_SIZE_FROZEN_THRONE : DOODAD_MINIMUM_SIZE_REIGN_OF_CHAOS
	count := read_count(&reader, minimum_size) or_return
	building.doodads = make([]Placed_Doodad, count, allocator)
	for &doodad in building.doodads {
		parse_doodad(&reader, &doodad, version, allocator) or_return
	}

	// The special-doodad section follows unconditionally, including in
	// v7 files, where the corpus shows it present with its own version
	// integer and (in every Reign of Chaos map) a zero count.
	special_version, special_version_ok := read_i32(&reader)
	if !special_version_ok {
		return {}, .Truncated
	}
	if special_version != SPECIAL_DOODAD_VERSION {
		return {}, .Unsupported_Version
	}
	building.special_doodad_version = special_version
	special_count := read_count(&reader, SPECIAL_DOODAD_SIZE) or_return
	building.special_doodads = make([]Special_Doodad, special_count, allocator)
	for &special in building.special_doodads {
		if !read_bytes(&reader, special.type_id[:]) {
			return {}, .Truncated
		}
		variation, variation_ok := read_i32(&reader)
		grid_x, grid_x_ok := read_i32(&reader)
		grid_y, grid_y_ok := read_i32(&reader)
		if !variation_ok || !grid_x_ok || !grid_y_ok {
			return {}, .Truncated
		}
		special.variation = variation
		special.grid_x = grid_x
		special.grid_y = grid_y
	}

	if reader_remaining(&reader) != 0 {
		return {}, .Trailing_Bytes
	}
	return building, .None
}

@(private)
parse_doodad :: proc(
	reader: ^Reader,
	doodad: ^Placed_Doodad,
	version: i32,
	allocator: runtime.Allocator,
) -> (
	error: Error,
) {
	if !read_bytes(reader, doodad.type_id[:]) {
		return .Truncated
	}
	variation, variation_ok := read_i32(reader)
	position, position_ok := read_vector3(reader)
	rotation, rotation_ok := read_f32(reader)
	scale, scale_ok := read_vector3(reader)
	flags, flags_ok := read_u8(reader)
	life_percentage, life_ok := read_u8(reader)
	if !variation_ok || !position_ok || !rotation_ok || !scale_ok {
		return .Truncated
	}
	if !flags_ok || !life_ok {
		return .Truncated
	}
	doodad.variation = variation
	doodad.position = position
	doodad.rotation = rotation
	doodad.scale = scale
	doodad.flags = flags
	doodad.life_percentage = life_percentage

	// v7 has no drop data at all, which the HiveWE wiki states outright
	// and War3Net gates on the same version. No stock map exercises the
	// v8 path with data: all 567888 v8 doodads carry item table id -1
	// and zero drop sets, so the populated shape is covered by the
	// synthetic fixtures only.
	doodad.item_table_id = NO_ITEM_TABLE
	if version == VERSION_FROZEN_THRONE {
		item_table_id, item_table_ok := read_i32(reader)
		if !item_table_ok {
			return .Truncated
		}
		doodad.item_table_id = item_table_id
		parse_item_sets(reader, &doodad.dropped_item_sets, allocator) or_return
	}

	creation_number, creation_ok := read_i32(reader)
	if !creation_ok {
		return .Truncated
	}
	doodad.creation_number = creation_number
	return .None
}
