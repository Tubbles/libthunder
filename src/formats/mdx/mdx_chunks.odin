package mdx

// Per-chunk item parsers. Layouts follow Magos's spec except where the
// corpus proved it wrong or incomplete; every such deviation carries a
// comment naming a corpus file that exhibits the actual layout.

import "base:runtime"

@(private)
NODE_MINIMUM_SIZE :: 96 // u32 size + 80-byte name + object/parent/flags

@(private)
LAYER_MINIMUM_SIZE :: 28 // u32 size + six fixed fields

@(private)
SEQUENCE_EXTENT_SIZE :: 28 // bounds radius + minimum + maximum

@(private)
parse_version_chunk :: proc(reader: ^Reader, model: ^Model) -> Error {
	version, ok := read_u32(reader)
	if !ok {
		return .Corrupt_Chunk
	}
	if version != SUPPORTED_VERSION {
		return .Unsupported_Version
	}
	model.version = version
	return .None
}

@(private)
parse_model_chunk :: proc(reader: ^Reader, model: ^Model, allocator: runtime.Allocator) -> Error {
	model.name = read_fixed_string(reader, 80, allocator) or_return
	model.animation_file_name = read_fixed_string(reader, 260, allocator) or_return
	if !read_extent(reader, &model.extent) || !read_value(reader, &model.blend_time) {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_sequence :: proc(reader: ^Reader, sequence: ^Sequence, allocator: runtime.Allocator) -> Error {
	sequence.name = read_fixed_string(reader, 80, allocator) or_return
	fields_ok :=
		read_value(reader, &sequence.interval_start) &&
		read_value(reader, &sequence.interval_end) &&
		read_value(reader, &sequence.move_speed) &&
		read_value(reader, &sequence.flags) &&
		read_value(reader, &sequence.rarity) &&
		read_value(reader, &sequence.sync_point) &&
		read_extent(reader, &sequence.extent)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_global_sequence :: proc(reader: ^Reader, duration: ^u32, allocator: runtime.Allocator) -> Error {
	_ = allocator
	if !read_value(reader, duration) {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_texture :: proc(reader: ^Reader, texture: ^Texture, allocator: runtime.Allocator) -> Error {
	if !read_value(reader, &texture.replaceable_id) {
		return .Corrupt_Chunk
	}
	texture.file_name = read_fixed_string(reader, 260, allocator) or_return
	if !read_value(reader, &texture.flags) {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_texture_animation :: proc(reader: ^Reader, texture_animation: ^Texture_Animation, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KTAT":
			parse_track_set(&sub, &texture_animation.translation, allocator) or_return
		case "KTAR":
			parse_track_set(&sub, &texture_animation.rotation, allocator) or_return
		case "KTAS":
			parse_track_set(&sub, &texture_animation.scaling, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_material :: proc(reader: ^Reader, material: ^Material, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 12)
	if !ok {
		return .Corrupt_Chunk
	}
	if !read_value(&sub, &material.priority_plane) || !read_value(&sub, &material.flags) {
		return .Corrupt_Chunk
	}
	if reader_remaining(&sub) > 0 {
		if !expect_tag(&sub, "LAYS") {
			return .Corrupt_Chunk
		}
		layer_count, count_ok := read_u32(&sub)
		if !count_ok || i64(layer_count) * LAYER_MINIMUM_SIZE > i64(reader_remaining(&sub)) {
			return .Corrupt_Chunk
		}
		material.layers = make([]Layer, int(layer_count), allocator)
		for &layer in material.layers {
			parse_layer(&sub, &layer, allocator) or_return
		}
		if reader_remaining(&sub) != 0 {
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_layer :: proc(reader: ^Reader, layer: ^Layer, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, LAYER_MINIMUM_SIZE)
	if !ok {
		return .Corrupt_Chunk
	}
	fields_ok :=
		read_value(&sub, &layer.filter_mode) &&
		read_value(&sub, &layer.shading_flags) &&
		read_value(&sub, &layer.texture_id) &&
		read_value(&sub, &layer.texture_animation_id) &&
		read_value(&sub, &layer.coordinate_id) &&
		read_value(&sub, &layer.alpha)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KMTA":
			parse_track_set(&sub, &layer.alpha_track, allocator) or_return
		case "KMTF":
			parse_track_set(&sub, &layer.texture_id_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_geoset :: proc(reader: ^Reader, geoset: ^Geoset, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	read_counted_array(&sub, "VRTX", &geoset.vertices, allocator) or_return
	read_counted_array(&sub, "NRMS", &geoset.normals, allocator) or_return
	read_counted_array(&sub, "PTYP", &geoset.face_type_groups, allocator) or_return
	read_counted_array(&sub, "PCNT", &geoset.face_group_index_counts, allocator) or_return
	read_counted_array(&sub, "PVTX", &geoset.face_indices, allocator) or_return
	read_counted_array(&sub, "GNDX", &geoset.vertex_groups, allocator) or_return
	read_counted_array(&sub, "MTGC", &geoset.matrix_group_sizes, allocator) or_return
	read_counted_array(&sub, "MATS", &geoset.matrix_indices, allocator) or_return
	fields_ok :=
		read_value(&sub, &geoset.material_id) &&
		read_value(&sub, &geoset.selection_group) &&
		read_value(&sub, &geoset.selection_flags) &&
		read_extent(&sub, &geoset.extent)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	sequence_extent_count, extent_count_ok := read_u32(&sub)
	if !extent_count_ok || i64(sequence_extent_count) * SEQUENCE_EXTENT_SIZE > i64(reader_remaining(&sub)) {
		return .Corrupt_Chunk
	}
	// Magos lists the per-sequence extents as minimum plus maximum (24
	// bytes); the corpus stores bounds radius, minimum, maximum (28
	// bytes). Example: Units\Human\Footman\Footman.mdx, 13 extents per
	// geoset. With 24-byte extents roughly half the corpus misparses.
	geoset.sequence_extents = make([]Extent, int(sequence_extent_count), allocator)
	for &sequence_extent in geoset.sequence_extents {
		if !read_extent(&sub, &sequence_extent) {
			return .Corrupt_Chunk
		}
	}
	if !expect_tag(&sub, "UVAS") {
		return .Corrupt_Chunk
	}
	// The UVAS count is the number of texture coordinate sets; that
	// many UVBS sub-chunks follow (1 to 3 in the corpus). Each set
	// costs at least the 8-byte UVBS header.
	set_count, set_count_ok := read_u32(&sub)
	if !set_count_ok || i64(set_count) * 8 > i64(reader_remaining(&sub)) {
		return .Corrupt_Chunk
	}
	geoset.texture_coordinate_sets = make([][][2]f32, int(set_count), allocator)
	for &texture_coordinate_set in geoset.texture_coordinate_sets {
		read_counted_array(&sub, "UVBS", &texture_coordinate_set, allocator) or_return
	}
	if reader_remaining(&sub) != 0 {
		return .Corrupt_Chunk
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_geoset_animation :: proc(reader: ^Reader, geoset_animation: ^Geoset_Animation, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 28)
	if !ok {
		return .Corrupt_Chunk
	}
	fields_ok :=
		read_value(&sub, &geoset_animation.alpha) &&
		read_value(&sub, &geoset_animation.flags) &&
		read_value(&sub, &geoset_animation.color) &&
		read_value(&sub, &geoset_animation.geoset_id)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KGAO":
			parse_track_set(&sub, &geoset_animation.alpha_track, allocator) or_return
		case "KGAC":
			parse_track_set(&sub, &geoset_animation.color_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_node :: proc(reader: ^Reader, node: ^Node, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, NODE_MINIMUM_SIZE)
	if !ok {
		return .Corrupt_Chunk
	}
	node.name = read_fixed_string(&sub, 80, allocator) or_return
	fields_ok :=
		read_value(&sub, &node.object_id) &&
		read_value(&sub, &node.parent_id) &&
		read_value(&sub, &node.flags)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KGTR":
			parse_track_set(&sub, &node.translation, allocator) or_return
		case "KGRT":
			parse_track_set(&sub, &node.rotation, allocator) or_return
		case "KGSC":
			parse_track_set(&sub, &node.scaling, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_bone :: proc(reader: ^Reader, bone: ^Bone, allocator: runtime.Allocator) -> Error {
	parse_node(reader, &bone.node, allocator) or_return
	if !read_value(reader, &bone.geoset_id) || !read_value(reader, &bone.geoset_animation_id) {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_helper :: proc(reader: ^Reader, helper: ^Helper, allocator: runtime.Allocator) -> Error {
	return parse_node(reader, &helper.node, allocator)
}

@(private)
parse_light :: proc(reader: ^Reader, light: ^Light, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	parse_node(&sub, &light.node, allocator) or_return
	// Magos types the attenuation fields as DWORD; the corpus stores
	// floats (e.g. Buildings\Other\CentaurTent1\CentaurTent1.mdx has
	// attenuation 80.0 to 200.0).
	fields_ok :=
		read_value(&sub, &light.light_type) &&
		read_value(&sub, &light.attenuation_start) &&
		read_value(&sub, &light.attenuation_end) &&
		read_value(&sub, &light.color) &&
		read_value(&sub, &light.intensity) &&
		read_value(&sub, &light.ambient_color) &&
		read_value(&sub, &light.ambient_intensity)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KLAV":
			parse_track_set(&sub, &light.visibility_track, allocator) or_return
		case "KLAC":
			parse_track_set(&sub, &light.color_track, allocator) or_return
		case "KLAI":
			parse_track_set(&sub, &light.intensity_track, allocator) or_return
		case "KLBC":
			parse_track_set(&sub, &light.ambient_color_track, allocator) or_return
		case "KLBI":
			parse_track_set(&sub, &light.ambient_intensity_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_attachment :: proc(reader: ^Reader, attachment: ^Attachment, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	parse_node(&sub, &attachment.node, allocator) or_return
	attachment.path = read_fixed_string(&sub, 260, allocator) or_return
	if !read_value(&sub, &attachment.attachment_id) {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KATV":
			parse_track_set(&sub, &attachment.visibility_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_pivot_point :: proc(reader: ^Reader, pivot_point: ^[3]f32, allocator: runtime.Allocator) -> Error {
	_ = allocator
	if !read_value(reader, pivot_point) {
		return .Corrupt_Chunk
	}
	return .None
}

@(private)
parse_particle_emitter :: proc(reader: ^Reader, particle_emitter: ^Particle_Emitter, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	parse_node(&sub, &particle_emitter.node, allocator) or_return
	head_ok :=
		read_value(&sub, &particle_emitter.emission_rate) &&
		read_value(&sub, &particle_emitter.gravity) &&
		read_value(&sub, &particle_emitter.longitude) &&
		read_value(&sub, &particle_emitter.latitude)
	if !head_ok {
		return .Corrupt_Chunk
	}
	particle_emitter.spawn_model_file_name = read_fixed_string(&sub, 260, allocator) or_return
	tail_ok :=
		read_value(&sub, &particle_emitter.life_span) &&
		read_value(&sub, &particle_emitter.initial_velocity)
	if !tail_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KPEV":
			parse_track_set(&sub, &particle_emitter.visibility_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_particle_emitter_2 :: proc(reader: ^Reader, particle_emitter_2: ^Particle_Emitter_2, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	parse_node(&sub, &particle_emitter_2.node, allocator) or_return
	fields_ok :=
		read_value(&sub, &particle_emitter_2.speed) &&
		read_value(&sub, &particle_emitter_2.variation) &&
		read_value(&sub, &particle_emitter_2.latitude) &&
		read_value(&sub, &particle_emitter_2.gravity) &&
		read_value(&sub, &particle_emitter_2.life_span) &&
		read_value(&sub, &particle_emitter_2.emission_rate) &&
		read_value(&sub, &particle_emitter_2.length) &&
		read_value(&sub, &particle_emitter_2.width) &&
		read_value(&sub, &particle_emitter_2.filter_mode) &&
		read_value(&sub, &particle_emitter_2.rows) &&
		read_value(&sub, &particle_emitter_2.columns) &&
		read_value(&sub, &particle_emitter_2.head_or_tail) &&
		read_value(&sub, &particle_emitter_2.tail_length) &&
		read_value(&sub, &particle_emitter_2.time) &&
		read_value(&sub, &particle_emitter_2.segment_colors) &&
		read_value(&sub, &particle_emitter_2.segment_alphas) &&
		read_value(&sub, &particle_emitter_2.segment_scaling) &&
		read_value(&sub, &particle_emitter_2.head_interval) &&
		read_value(&sub, &particle_emitter_2.head_decay_interval) &&
		read_value(&sub, &particle_emitter_2.tail_interval) &&
		read_value(&sub, &particle_emitter_2.tail_decay_interval) &&
		read_value(&sub, &particle_emitter_2.texture_id) &&
		read_value(&sub, &particle_emitter_2.squirt) &&
		read_value(&sub, &particle_emitter_2.priority_plane) &&
		read_value(&sub, &particle_emitter_2.replaceable_id)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KP2V":
			parse_track_set(&sub, &particle_emitter_2.visibility_track, allocator) or_return
		case "KP2E":
			parse_track_set(&sub, &particle_emitter_2.emission_rate_track, allocator) or_return
		case "KP2W":
			parse_track_set(&sub, &particle_emitter_2.width_track, allocator) or_return
		case "KP2N":
			parse_track_set(&sub, &particle_emitter_2.length_track, allocator) or_return
		case "KP2S":
			parse_track_set(&sub, &particle_emitter_2.speed_track, allocator) or_return
		case "KP2L":
			// Magos omits the latitude track; 31 corpus files carry it,
			// e.g. Abilities\Spells\Other\Monsoon\MonsoonBoltTarget.mdx.
			parse_track_set(&sub, &particle_emitter_2.latitude_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_ribbon_emitter :: proc(reader: ^Reader, ribbon_emitter: ^Ribbon_Emitter, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	parse_node(&sub, &ribbon_emitter.node, allocator) or_return
	fields_ok :=
		read_value(&sub, &ribbon_emitter.height_above) &&
		read_value(&sub, &ribbon_emitter.height_below) &&
		read_value(&sub, &ribbon_emitter.alpha) &&
		read_value(&sub, &ribbon_emitter.color) &&
		read_value(&sub, &ribbon_emitter.life_span) &&
		read_value(&sub, &ribbon_emitter.texture_slot) &&
		read_value(&sub, &ribbon_emitter.emission_rate) &&
		read_value(&sub, &ribbon_emitter.rows) &&
		read_value(&sub, &ribbon_emitter.columns) &&
		read_value(&sub, &ribbon_emitter.material_id) &&
		read_value(&sub, &ribbon_emitter.gravity)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KRVS":
			parse_track_set(&sub, &ribbon_emitter.visibility_track, allocator) or_return
		case "KRHA":
			parse_track_set(&sub, &ribbon_emitter.height_above_track, allocator) or_return
		case "KRHB":
			parse_track_set(&sub, &ribbon_emitter.height_below_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_event_object :: proc(reader: ^Reader, event_object: ^Event_Object, allocator: runtime.Allocator) -> Error {
	parse_node(reader, &event_object.node, allocator) or_return
	event_object.global_sequence_id = NO_ID
	// KEVT differs from the generic track layout: u32 count, u32 global
	// sequence id (no interpolation type), then bare times. Every event
	// object in the corpus carries one, but it is optional here because
	// nothing in the container guarantees it.
	if peek_tag_matches(reader, "KEVT") {
		reader.offset += 4
		count, count_ok := read_u32(reader)
		global_sequence_id, global_ok := read_u32(reader)
		if !count_ok || !global_ok {
			return .Corrupt_Chunk
		}
		event_object.global_sequence_id = global_sequence_id
		return read_array(reader, count, &event_object.times, allocator)
	}
	return .None
}

@(private)
parse_camera :: proc(reader: ^Reader, camera: ^Camera, allocator: runtime.Allocator) -> Error {
	sub, item_end, ok := begin_sized_item(reader, 4)
	if !ok {
		return .Corrupt_Chunk
	}
	camera.name = read_fixed_string(&sub, 80, allocator) or_return
	// Magos types field of view and the clipping planes as DWORD; the
	// corpus stores floats (CentaurTent1.mdx: 0.787814, 1000.0, 8.0).
	fields_ok :=
		read_value(&sub, &camera.position) &&
		read_value(&sub, &camera.field_of_view) &&
		read_value(&sub, &camera.far_clipping_plane) &&
		read_value(&sub, &camera.near_clipping_plane) &&
		read_value(&sub, &camera.target_position)
	if !fields_ok {
		return .Corrupt_Chunk
	}
	for reader_remaining(&sub) > 0 {
		tag, tag_ok := read_tag(&sub)
		if !tag_ok {
			return .Corrupt_Chunk
		}
		switch string(tag[:]) {
		case "KCTR":
			parse_track_set(&sub, &camera.position_track, allocator) or_return
		case "KTTR":
			parse_track_set(&sub, &camera.target_track, allocator) or_return
		case "KCRL":
			// Magos defines KCRL but omits it from the camera layout;
			// 124 corpus files carry it, e.g.
			// Buildings\Human\HumanTower\HumanTower.mdx.
			parse_track_set(&sub, &camera.rotation_track, allocator) or_return
		case:
			return .Corrupt_Chunk
		}
	}
	reader.offset = item_end
	return .None
}

@(private)
parse_collision_shape :: proc(reader: ^Reader, collision_shape: ^Collision_Shape, allocator: runtime.Allocator) -> Error {
	parse_node(reader, &collision_shape.node, allocator) or_return
	if !read_value(reader, &collision_shape.shape_type) {
		return .Corrupt_Chunk
	}
	// The corpus contains only type 0 (box, 276 shapes) and type 2
	// (sphere, 619 shapes); other types are rejected because their
	// layout cannot be verified against anything.
	switch collision_shape.shape_type {
	case 0:
		collision_shape.vertex_count = 2
		if !read_value(reader, &collision_shape.vertices[0]) || !read_value(reader, &collision_shape.vertices[1]) {
			return .Corrupt_Chunk
		}
	case 2:
		collision_shape.vertex_count = 1
		if !read_value(reader, &collision_shape.vertices[0]) || !read_value(reader, &collision_shape.bounds_radius) {
			return .Corrupt_Chunk
		}
	case:
		return .Corrupt_Chunk
	}
	return .None
}
