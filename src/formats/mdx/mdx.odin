package mdx

// Reader for the classic Warcraft III binary model format (MDX, the
// "MDLX" container, format version 800 as shipped with patch 1.29.2).
// The file is a flat sequence of tagged chunks (4-byte tag plus u32
// little-endian size); this parser produces typed data for every chunk
// tag that occurs in the 1.29.2 corpus (WI-0009 survey) and skips
// unknown tags by their size field.
//
// Primary reference: Magos's "The MDX file format!" community spec
// (work/mdx-reference/magos-mdx-spec.txt). Where the spec and the
// corpus disagree, the corpus is the authority; each such deviation is
// commented at its parse site in mdx_chunks.odin.

import "base:runtime"

Error :: enum {
	None,
	Invalid_Header,
	Unsupported_Version,
	Corrupt_Chunk,
}

SUPPORTED_VERSION :: 800

Model :: struct {
	version:             u32,
	name:                string,
	animation_file_name: string,
	extent:              Extent,
	blend_time:          u32,
	sequences:           []Sequence, // SEQS
	global_sequences:    []u32, // GLBS durations
	textures:            []Texture, // TEXS
	texture_animations:  []Texture_Animation, // TXAN
	materials:           []Material, // MTLS
	geosets:             []Geoset, // GEOS
	geoset_animations:   []Geoset_Animation, // GEOA
	bones:               []Bone, // BONE
	lights:              []Light, // LITE
	helpers:             []Helper, // HELP
	attachments:         []Attachment, // ATCH
	pivot_points:        [][3]f32, // PIVT
	particle_emitters:   []Particle_Emitter, // PREM
	particle_emitters_2: []Particle_Emitter_2, // PRE2
	ribbon_emitters:     []Ribbon_Emitter, // RIBB
	event_objects:       []Event_Object, // EVTS
	cameras:             []Camera, // CAMS
	collision_shapes:    []Collision_Shape, // CLID
	allocator:           runtime.Allocator,
}

// Parses a complete MDX file. On error the partially built model is
// freed and a zero value is returned.
parse :: proc(data: []u8, allocator := context.allocator) -> (model: Model, error: Error) {
	if len(data) < 4 || data[0] != 'M' || data[1] != 'D' || data[2] != 'L' || data[3] != 'X' {
		return {}, .Invalid_Header
	}
	building := Model {
		allocator = allocator,
	}
	walk_error := parse_chunks(data, &building, allocator)
	if walk_error != .None {
		destroy(&building)
		return {}, walk_error
	}
	return building, .None
}

@(private)
parse_chunks :: proc(data: []u8, model: ^Model, allocator: runtime.Allocator) -> Error {
	reader := Reader {
		data   = data,
		offset = 4,
	}
	for reader_remaining(&reader) > 0 {
		tag, tag_ok := read_tag(&reader)
		chunk_size, size_ok := read_u32(&reader)
		if !tag_ok || !size_ok || int(chunk_size) > reader_remaining(&reader) {
			return .Corrupt_Chunk
		}
		chunk_end := reader.offset + int(chunk_size)
		chunk_reader := Reader {
			data   = data[:chunk_end],
			offset = reader.offset,
		}
		switch string(tag[:]) {
		case "VERS":
			parse_version_chunk(&chunk_reader, model) or_return
		case "MODL":
			parse_model_chunk(&chunk_reader, model, allocator) or_return
		case "SEQS":
			parse_item_list(&chunk_reader, &model.sequences, parse_sequence, allocator) or_return
		case "GLBS":
			parse_item_list(&chunk_reader, &model.global_sequences, parse_global_sequence, allocator) or_return
		case "TEXS":
			parse_item_list(&chunk_reader, &model.textures, parse_texture, allocator) or_return
		case "TXAN":
			parse_item_list(&chunk_reader, &model.texture_animations, parse_texture_animation, allocator) or_return
		case "MTLS":
			parse_item_list(&chunk_reader, &model.materials, parse_material, allocator) or_return
		case "GEOS":
			parse_item_list(&chunk_reader, &model.geosets, parse_geoset, allocator) or_return
		case "GEOA":
			parse_item_list(&chunk_reader, &model.geoset_animations, parse_geoset_animation, allocator) or_return
		case "BONE":
			parse_item_list(&chunk_reader, &model.bones, parse_bone, allocator) or_return
		case "LITE":
			parse_item_list(&chunk_reader, &model.lights, parse_light, allocator) or_return
		case "HELP":
			parse_item_list(&chunk_reader, &model.helpers, parse_helper, allocator) or_return
		case "ATCH":
			parse_item_list(&chunk_reader, &model.attachments, parse_attachment, allocator) or_return
		case "PIVT":
			parse_item_list(&chunk_reader, &model.pivot_points, parse_pivot_point, allocator) or_return
		case "PREM":
			parse_item_list(&chunk_reader, &model.particle_emitters, parse_particle_emitter, allocator) or_return
		case "PRE2":
			parse_item_list(&chunk_reader, &model.particle_emitters_2, parse_particle_emitter_2, allocator) or_return
		case "RIBB":
			parse_item_list(&chunk_reader, &model.ribbon_emitters, parse_ribbon_emitter, allocator) or_return
		case "EVTS":
			parse_item_list(&chunk_reader, &model.event_objects, parse_event_object, allocator) or_return
		case "CAMS":
			parse_item_list(&chunk_reader, &model.cameras, parse_camera, allocator) or_return
		case "CLID":
			parse_item_list(&chunk_reader, &model.collision_shapes, parse_collision_shape, allocator) or_return
		case:
		// Unknown top-level chunks are tolerated and skipped by size.
		}
		reader.offset = chunk_end
	}
	return .None
}

// Parses one chunk that is a plain concatenation of items, appending
// until the chunk region is exhausted. Every item parser either
// consumes at least one byte or fails, so the loop terminates. The
// item slice is attached to the model before any error is returned, so
// destroy can free partially parsed content.
@(private)
parse_item_list :: proc(
	reader: ^Reader,
	list: ^[]$Item,
	parse_item: proc(reader: ^Reader, item: ^Item, allocator: runtime.Allocator) -> Error,
	allocator: runtime.Allocator,
) -> Error {
	if list^ != nil {
		// No corpus file repeats a top-level chunk tag; a repeat would
		// clobber the earlier chunk's data, so it is treated as corrupt.
		return .Corrupt_Chunk
	}
	items := make([dynamic]Item, allocator)
	error := Error.None
	for reader_remaining(reader) > 0 && error == .None {
		append(&items, Item{})
		error = parse_item(reader, &items[len(items) - 1], allocator)
	}
	shrink(&items)
	list^ = items[:]
	return error
}

// Frees everything parse allocated. Safe on a zero-value model and
// after a partial parse.
destroy :: proc(model: ^Model) {
	allocator := model.allocator
	delete(model.name, allocator)
	delete(model.animation_file_name, allocator)
	for &sequence in model.sequences {
		delete(sequence.name, allocator)
	}
	delete(model.sequences, allocator)
	delete(model.global_sequences, allocator)
	for &texture in model.textures {
		delete(texture.file_name, allocator)
	}
	delete(model.textures, allocator)
	for &texture_animation in model.texture_animations {
		destroy_track_set(&texture_animation.translation, allocator)
		destroy_track_set(&texture_animation.rotation, allocator)
		destroy_track_set(&texture_animation.scaling, allocator)
	}
	delete(model.texture_animations, allocator)
	for &material in model.materials {
		for &layer in material.layers {
			destroy_track_set(&layer.alpha_track, allocator)
			destroy_track_set(&layer.texture_id_track, allocator)
		}
		delete(material.layers, allocator)
	}
	delete(model.materials, allocator)
	for &geoset in model.geosets {
		delete(geoset.vertices, allocator)
		delete(geoset.normals, allocator)
		delete(geoset.face_type_groups, allocator)
		delete(geoset.face_group_index_counts, allocator)
		delete(geoset.face_indices, allocator)
		delete(geoset.vertex_groups, allocator)
		delete(geoset.matrix_group_sizes, allocator)
		delete(geoset.matrix_indices, allocator)
		delete(geoset.sequence_extents, allocator)
		for &texture_coordinate_set in geoset.texture_coordinate_sets {
			delete(texture_coordinate_set, allocator)
		}
		delete(geoset.texture_coordinate_sets, allocator)
	}
	delete(model.geosets, allocator)
	for &geoset_animation in model.geoset_animations {
		destroy_track_set(&geoset_animation.alpha_track, allocator)
		destroy_track_set(&geoset_animation.color_track, allocator)
	}
	delete(model.geoset_animations, allocator)
	for &bone in model.bones {
		destroy_node(&bone.node, allocator)
	}
	delete(model.bones, allocator)
	for &light in model.lights {
		destroy_node(&light.node, allocator)
		destroy_track_set(&light.visibility_track, allocator)
		destroy_track_set(&light.color_track, allocator)
		destroy_track_set(&light.intensity_track, allocator)
		destroy_track_set(&light.ambient_color_track, allocator)
		destroy_track_set(&light.ambient_intensity_track, allocator)
	}
	delete(model.lights, allocator)
	for &helper in model.helpers {
		destroy_node(&helper.node, allocator)
	}
	delete(model.helpers, allocator)
	for &attachment in model.attachments {
		destroy_node(&attachment.node, allocator)
		delete(attachment.path, allocator)
		destroy_track_set(&attachment.visibility_track, allocator)
	}
	delete(model.attachments, allocator)
	delete(model.pivot_points, allocator)
	for &particle_emitter in model.particle_emitters {
		destroy_node(&particle_emitter.node, allocator)
		delete(particle_emitter.spawn_model_file_name, allocator)
		destroy_track_set(&particle_emitter.visibility_track, allocator)
	}
	delete(model.particle_emitters, allocator)
	for &particle_emitter_2 in model.particle_emitters_2 {
		destroy_node(&particle_emitter_2.node, allocator)
		destroy_track_set(&particle_emitter_2.visibility_track, allocator)
		destroy_track_set(&particle_emitter_2.emission_rate_track, allocator)
		destroy_track_set(&particle_emitter_2.width_track, allocator)
		destroy_track_set(&particle_emitter_2.length_track, allocator)
		destroy_track_set(&particle_emitter_2.speed_track, allocator)
		destroy_track_set(&particle_emitter_2.latitude_track, allocator)
	}
	delete(model.particle_emitters_2, allocator)
	for &ribbon_emitter in model.ribbon_emitters {
		destroy_node(&ribbon_emitter.node, allocator)
		destroy_track_set(&ribbon_emitter.visibility_track, allocator)
		destroy_track_set(&ribbon_emitter.height_above_track, allocator)
		destroy_track_set(&ribbon_emitter.height_below_track, allocator)
	}
	delete(model.ribbon_emitters, allocator)
	for &event_object in model.event_objects {
		destroy_node(&event_object.node, allocator)
		delete(event_object.times, allocator)
	}
	delete(model.event_objects, allocator)
	for &camera in model.cameras {
		delete(camera.name, allocator)
		destroy_track_set(&camera.position_track, allocator)
		destroy_track_set(&camera.target_track, allocator)
		destroy_track_set(&camera.rotation_track, allocator)
	}
	delete(model.cameras, allocator)
	for &collision_shape in model.collision_shapes {
		destroy_node(&collision_shape.node, allocator)
	}
	delete(model.collision_shapes, allocator)
	model^ = {}
}

@(private)
destroy_node :: proc(node: ^Node, allocator: runtime.Allocator) {
	delete(node.name, allocator)
	destroy_track_set(&node.translation, allocator)
	destroy_track_set(&node.rotation, allocator)
	destroy_track_set(&node.scaling, allocator)
}
