package gamedata

// Reading the whole gameplay database out of the game's archives.
//
// Archive priority is War3xLocal > War3x > War3Local > War3, and a
// member is read from the first archive that has it. Only one
// gameplay-data member in the 1.29.2 corpus actually differs between
// archives, Units\NightElfAbilityStrings.txt, where War3xLocal's copy
// drops a clause from ability AEtq's research tooltip; every
// Units\*.slk and Doodads\Doodads.slk is byte identical across the
// archives that carry it.

import "core:slice"
import "core:strings"
import mpq "thunder:formats/mpq"
import object_data "thunder:formats/object_data"

// The base archives in priority order, highest first.
BASE_ARCHIVES :: [?]string{"War3xLocal.mpq", "War3x.mpq", "War3Local.mpq", "War3.mpq"}

// Profile TXT files live under Units\. The two profile files outside
// it (UI\war3skins.txt, UI\MiscUI.txt) back only SkinMetaData and
// MiscMetaData fields, which are section keyed rather than object
// keyed and are out of this layer's scope.
PROFILE_MEMBER_PREFIX :: "units\\"

// Archives to read through, highest priority first. The set does not
// own them: the caller opens and closes them.
Archive_Set :: struct {
	archives: []^mpq.Archive,
}

// Reads a member from the first archive that has it.
read_member :: proc(
	set: Archive_Set,
	name: string,
	allocator := context.allocator,
) -> (
	data: []u8,
	found: bool,
) {
	for archive in set.archives {
		member, error := mpq.read_file(archive, name, allocator)
		if error == .None {
			return member, true
		}
		delete(member, allocator)
	}
	return nil, false
}

// Loads the nine metadata SLKs, the eleven base tables and every
// profile TXT, in that order: the tables need the metadata to know
// which columns to read, and the profiles need the tables to know
// which family each section's rawcode belongs to. Object data is
// applied on top afterwards with load_map_object_data.
//
// On error the database holds whatever loaded before the failure and
// still has to be destroyed.
load_base :: proc(database: ^Database, set: Archive_Set) -> Error {
	metadata_members := METADATA_MEMBERS
	for source in Metadata_Source {
		content, found := read_member(set, metadata_members[source], database.allocator)
		defer delete(content, database.allocator)
		if !found {
			return .Missing_Member
		}
		load_metadata(database, source, string(content)) or_return
	}

	table_members := TABLE_MEMBERS
	for table in Table {
		member := table_members[table]
		if len(member) == 0 {
			continue
		}
		content, found := read_member(set, member, database.allocator)
		defer delete(content, database.allocator)
		if !found {
			return .Missing_Member
		}
		load_table(database, table, string(content)) or_return
	}

	names := profile_member_names(set, database.allocator)
	defer {
		for name in names {
			delete(name, database.allocator)
		}
		delete(names)
	}
	for name in names {
		content, found := read_member(set, name, database.allocator)
		defer delete(content, database.allocator)
		if !found {
			continue
		}
		load_profile(database, string(content)) or_return
	}
	return .None
}

// Applies every object-data member of one map or campaign archive.
// `prefix` is "war3map" for a map and "war3campaign" for the members a
// .w3n campaign archive carries directly. Members the archive does not
// have are skipped; a member that fails to parse is an error, since
// the whole 61-file corpus parses to exact end of file.
load_map_object_data :: proc(
	database: ^Database,
	archive: ^mpq.Archive,
	prefix := "war3map",
) -> (
	files: int,
	error: Error,
) {
	extensions := [?]string{"w3u", "w3t", "w3b", "w3d", "w3a", "w3h", "w3q"}
	for extension in extensions {
		member := strings.concatenate({prefix, ".", extension}, database.allocator)
		defer delete(member, database.allocator)
		data, read_error := mpq.read_file(archive, member, database.allocator)
		defer delete(data, database.allocator)
		if read_error != .None {
			continue
		}
		// The shape comes from the extension, never from the content:
		// the container has no in-band shape marker, and three corpus
		// files parse "successfully" with the wrong shape (WI-0011).
		shape, shape_known := object_data.shape_for_extension(extension)
		kind, kind_known := kind_for_extension(extension)
		if !shape_known || !kind_known {
			return files, .Invalid_Object_Data
		}
		parsed, parse_error := object_data.parse(data, shape, database.allocator)
		defer object_data.destroy(&parsed)
		if parse_error != .None {
			return files, .Invalid_Object_Data
		}
		apply_object_data(database, &parsed, kind) or_return
		files += 1
	}
	return files, .None
}

// The metadata is loaded through the database so the load counters
// stay in one place.
load_metadata :: proc(database: ^Database, source: Metadata_Source, content: string) -> Error {
	return metadata_add(&database.metadata, source, content, &database.stats)
}

// Every Units\*.txt named by any archive's listfile, lowercased,
// deduplicated and sorted so the load order is deterministic. MPQ
// member lookup is case insensitive, so the lowercased name reads the
// same member the listfile spelled.
@(private)
profile_member_names :: proc(set: Archive_Set, allocator := context.allocator) -> []string {
	seen := make(map[string]bool, allocator)
	defer delete(seen)
	names := make([dynamic]string, allocator)
	for archive in set.archives {
		listfile, error := mpq.read_file(archive, "(listfile)", allocator)
		defer delete(listfile, allocator)
		if error != .None {
			continue
		}
		text := string(listfile)
		for line in strings.split_lines_iterator(&text) {
			entry := strings.trim_space(line)
			if len(entry) == 0 {
				continue
			}
			name := strings.to_lower(entry, allocator)
			if !strings.has_prefix(name, PROFILE_MEMBER_PREFIX) ||
			   !strings.has_suffix(name, ".txt") ||
			   name in seen {
				delete(name, allocator)
				continue
			}
			seen[name] = true
			append(&names, name)
		}
	}
	slice.sort(names[:])
	return names[:]
}
