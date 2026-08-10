package w3i

// Bounds-checked little-endian reading plus the version-gated parse.
// Validation arithmetic on file-supplied counts runs in i64, before
// any allocation, so a 32-bit int target cannot wrap a product into a
// passing check (same approach as thunder:formats/mdx).

import "base:runtime"
import "core:strings"

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

@(private)
read_bytes :: proc(reader: ^Reader, buffer: []u8) -> bool {
	if reader_remaining(reader) < len(buffer) {
		return false
	}
	copy(buffer, reader.data[reader.offset:])
	reader.offset += len(buffer)
	return true
}

// Reads a NUL-terminated string and clones the content without the
// terminator. A string running to the end of the data is corrupt.
@(private)
read_string :: proc(reader: ^Reader, allocator: runtime.Allocator) -> (text: string, error: Error) {
	terminator := reader.offset
	for terminator < len(reader.data) && reader.data[terminator] != 0 {
		terminator += 1
	}
	if terminator == len(reader.data) {
		return "", .Unterminated_String
	}
	text = strings.clone(string(reader.data[reader.offset:terminator]), allocator)
	reader.offset = terminator + 1
	return text, .None
}

// Reads a list count and validates it against the remaining bytes at
// the given minimum bytes per element, before the caller allocates.
@(private)
// The element size is i64 so callers can pass computed sizes (for
// example 4 + 4 * column_count) without the expression itself being
// able to wrap on a 32-bit int target.
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

// Parses a complete war3map.w3i file (v18 or v25). On error the
// partially built info is freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (info: Map_Info, error: Error) {
	building: Map_Info
	building.allocator = allocator
	defer if error != .None {
		destroy(&building)
	}

	reader := Reader {
		data = data,
	}
	version, version_ok := read_u32(&reader)
	if !version_ok {
		return {}, .Truncated
	}
	if version != VERSION_REIGN_OF_CHAOS && version != VERSION_FROZEN_THRONE {
		return {}, .Unsupported_Version
	}
	building.version = version

	parse_header(&reader, &building, allocator) or_return
	parse_screens(&reader, &building, allocator) or_return
	if version >= VERSION_FROZEN_THRONE {
		parse_environment_block(&reader, &building, allocator) or_return
	}
	parse_players(&reader, &building, allocator) or_return
	parse_forces(&reader, &building, allocator) or_return

	// A 0xFF byte where the upgrade count belongs marks the rest of
	// the file absent (protected maps write this; mirrored from
	// War3Net's reader, which checks the first byte and backtracks).
	if reader_remaining(&reader) >= 1 && reader.data[reader.offset] == 0xFF {
		building.tail_skipped = true
		return building, .None
	}
	parse_upgrades(&reader, &building, allocator) or_return
	// The file may end cleanly right after the upgrade list (another
	// mirrored War3Net quirk).
	if reader_remaining(&reader) == 0 {
		return building, .None
	}
	parse_techs(&reader, &building, allocator) or_return
	parse_random_unit_tables(&reader, &building, allocator) or_return
	if version >= VERSION_FROZEN_THRONE {
		parse_random_item_tables(&reader, &building, allocator) or_return
	}
	return building, .None
}

@(private)
parse_header :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	map_version, map_version_ok := read_i32(reader)
	editor_version, editor_version_ok := read_i32(reader)
	if !map_version_ok || !editor_version_ok {
		return .Truncated
	}
	info.map_version = map_version
	info.editor_version = editor_version
	info.name = read_string(reader, allocator) or_return
	info.author = read_string(reader, allocator) or_return
	info.description = read_string(reader, allocator) or_return
	info.recommended_players = read_string(reader, allocator) or_return
	for index in 0 ..< 8 {
		bound, bound_ok := read_f32(reader)
		if !bound_ok {
			return .Truncated
		}
		info.camera_bounds[index] = bound
	}
	for index in 0 ..< 4 {
		complement, complement_ok := read_i32(reader)
		if !complement_ok {
			return .Truncated
		}
		info.camera_bounds_complements[index] = complement
	}
	playable_width, playable_width_ok := read_i32(reader)
	playable_height, playable_height_ok := read_i32(reader)
	flags, flags_ok := read_u32(reader)
	if !playable_width_ok || !playable_height_ok || !flags_ok || reader_remaining(reader) < 1 {
		return .Truncated
	}
	info.playable_width = playable_width
	info.playable_height = playable_height
	info.flags = flags
	info.tileset = reader.data[reader.offset]
	reader.offset += 1
	return .None
}

// The loading/prologue screen block. v18 stores preset numbers where
// v25 stores a background number plus custom path, and v25 adds the
// game data set (War3Net's v23 gate, below both supported versions).
@(private)
parse_screens :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	is_frozen_throne := info.version >= VERSION_FROZEN_THRONE
	if is_frozen_throne {
		number, number_ok := read_i32(reader)
		if !number_ok {
			return .Truncated
		}
		info.loading_screen_background_number = number
		info.loading_screen_path = read_string(reader, allocator) or_return
	} else {
		number, number_ok := read_i32(reader)
		if !number_ok {
			return .Truncated
		}
		info.campaign_background_number = number
	}
	info.loading_screen_text = read_string(reader, allocator) or_return
	info.loading_screen_title = read_string(reader, allocator) or_return
	info.loading_screen_subtitle = read_string(reader, allocator) or_return
	if is_frozen_throne {
		game_data_set, game_data_set_ok := read_i32(reader)
		if !game_data_set_ok {
			return .Truncated
		}
		info.game_data_set = game_data_set
		info.prologue_screen_path = read_string(reader, allocator) or_return
	} else {
		number, number_ok := read_i32(reader)
		if !number_ok {
			return .Truncated
		}
		info.loading_screen_number = number
	}
	info.prologue_screen_text = read_string(reader, allocator) or_return
	info.prologue_screen_title = read_string(reader, allocator) or_return
	info.prologue_screen_subtitle = read_string(reader, allocator) or_return
	return .None
}

// The v25 fog, weather, sound, light, and water block.
@(private)
parse_environment_block :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	fog_style, fog_style_ok := read_i32(reader)
	fog_start_z, fog_start_ok := read_f32(reader)
	fog_end_z, fog_end_ok := read_f32(reader)
	fog_density, fog_density_ok := read_f32(reader)
	if !fog_style_ok || !fog_start_ok || !fog_end_ok || !fog_density_ok {
		return .Truncated
	}
	info.fog_style = fog_style
	info.fog_start_z = fog_start_z
	info.fog_end_z = fog_end_z
	info.fog_density = fog_density
	if !read_bytes(reader, info.fog_color[:]) || !read_bytes(reader, info.global_weather_id[:]) {
		return .Truncated
	}
	info.sound_environment = read_string(reader, allocator) or_return
	if reader_remaining(reader) < 1 {
		return .Truncated
	}
	info.light_environment = reader.data[reader.offset]
	reader.offset += 1
	if !read_bytes(reader, info.water_tint[:]) {
		return .Truncated
	}
	return .None
}

@(private)
parse_players :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	// Fixed player fields plus one byte for the empty name.
	count := read_count(reader, 33) or_return
	info.players = make([]Player, count, allocator)
	for &player in info.players {
		id, id_ok := read_i32(reader)
		controller, controller_ok := read_i32(reader)
		race, race_ok := read_i32(reader)
		flags, flags_ok := read_u32(reader)
		if !id_ok || !controller_ok || !race_ok || !flags_ok {
			return .Truncated
		}
		player.id = id
		player.controller = controller
		player.race = race
		player.flags = flags
		player.name = read_string(reader, allocator) or_return
		start_x, start_x_ok := read_f32(reader)
		start_y, start_y_ok := read_f32(reader)
		ally_low, ally_low_ok := read_u32(reader)
		ally_high, ally_high_ok := read_u32(reader)
		if !start_x_ok || !start_y_ok || !ally_low_ok || !ally_high_ok {
			return .Truncated
		}
		player.start_x = start_x
		player.start_y = start_y
		player.ally_low_priorities = ally_low
		player.ally_high_priorities = ally_high
	}
	return .None
}

@(private)
parse_forces :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	// Two u32 fields plus one byte for the empty name.
	count := read_count(reader, 9) or_return
	info.forces = make([]Force, count, allocator)
	for &force in info.forces {
		flags, flags_ok := read_u32(reader)
		players, players_ok := read_u32(reader)
		if !flags_ok || !players_ok {
			return .Truncated
		}
		force.flags = flags
		force.players = players
		force.name = read_string(reader, allocator) or_return
	}
	return .None
}

@(private)
parse_upgrades :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	count := read_count(reader, 16) or_return
	info.upgrades = make([]Upgrade_Availability, count, allocator)
	for &upgrade in info.upgrades {
		players, players_ok := read_u32(reader)
		if !players_ok || !read_bytes(reader, upgrade.id[:]) {
			return .Truncated
		}
		level, level_ok := read_i32(reader)
		availability, availability_ok := read_i32(reader)
		if !level_ok || !availability_ok {
			return .Truncated
		}
		upgrade.players = players
		upgrade.level = level
		upgrade.availability = availability
	}
	return .None
}

@(private)
parse_techs :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	count := read_count(reader, 8) or_return
	info.techs = make([]Tech_Availability, count, allocator)
	for &tech in info.techs {
		players, players_ok := read_u32(reader)
		if !players_ok || !read_bytes(reader, tech.id[:]) {
			return .Truncated
		}
		tech.players = players
	}
	return .None
}

@(private)
parse_random_unit_tables :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	// Index, one name byte, and two counts at minimum per table.
	table_count := read_count(reader, 13) or_return
	info.random_unit_tables = make([]Random_Unit_Table, table_count, allocator)
	for &table in info.random_unit_tables {
		index, index_ok := read_i32(reader)
		if !index_ok {
			return .Truncated
		}
		table.index = index
		table.name = read_string(reader, allocator) or_return

		column_count := read_count(reader, 4) or_return
		table.widget_types = make([]i32, column_count, allocator)
		for &widget_type in table.widget_types {
			value, value_ok := read_i32(reader)
			if !value_ok {
				return .Truncated
			}
			widget_type = value
		}

		// Each line is a chance plus one id per column.
		line_count := read_count(reader, 4 + 4 * i64(column_count)) or_return
		table.lines = make([]Random_Unit_Line, line_count, allocator)
		for &line in table.lines {
			chance, chance_ok := read_i32(reader)
			if !chance_ok {
				return .Truncated
			}
			line.chance = chance
			line.unit_ids = make([][4]u8, column_count, allocator)
			for &unit_id in line.unit_ids {
				if !read_bytes(reader, unit_id[:]) {
					return .Truncated
				}
			}
		}
	}
	return .None
}

@(private)
parse_random_item_tables :: proc(reader: ^Reader, info: ^Map_Info, allocator: runtime.Allocator) -> (error: Error) {
	// Index, one name byte, and a set count at minimum per table.
	table_count := read_count(reader, 9) or_return
	info.random_item_tables = make([]Random_Item_Table, table_count, allocator)
	for &table in info.random_item_tables {
		index, index_ok := read_i32(reader)
		if !index_ok {
			return .Truncated
		}
		table.index = index
		table.name = read_string(reader, allocator) or_return

		set_count := read_count(reader, 4) or_return
		table.item_sets = make([]Random_Item_Set, set_count, allocator)
		for &item_set in table.item_sets {
			item_count := read_count(reader, 8) or_return
			item_set.items = make([]Random_Item, item_count, allocator)
			for &item in item_set.items {
				chance, chance_ok := read_i32(reader)
				if !chance_ok || !read_bytes(reader, item.id[:]) {
					return .Truncated
				}
				item.chance = chance
			}
		}
	}
	return .None
}
