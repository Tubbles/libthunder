package mdx

// Synthetic-fixture tests: hand-built MDX byte streams, no game data.
// The builder helpers append little-endian fields into a [dynamic]u8;
// sized items are built content-first so the inclusive size is exact.

import "core:testing"

@(private)
test_append_u32 :: proc(buffer: ^[dynamic]u8, value: u32) {
	append(buffer, u8(value), u8(value >> 8), u8(value >> 16), u8(value >> 24))
}

@(private)
test_append_f32 :: proc(buffer: ^[dynamic]u8, value: f32) {
	test_append_u32(buffer, transmute(u32)value)
}

@(private)
test_append_f32_values :: proc(buffer: ^[dynamic]u8, values: []f32) {
	for value in values {
		test_append_f32(buffer, value)
	}
}

@(private)
test_append_fixed_string :: proc(buffer: ^[dynamic]u8, text: string, length: int) {
	append(buffer, text)
	for _ in 0 ..< length - len(text) {
		append(buffer, 0)
	}
}

@(private)
test_append_chunk :: proc(buffer: ^[dynamic]u8, tag: string, content: []u8) {
	append(buffer, tag)
	test_append_u32(buffer, u32(len(content)))
	append(buffer, ..content)
}

// Appends a u32 inclusive size (content length plus the size field
// itself) followed by the content.
@(private)
test_append_sized_item :: proc(buffer: ^[dynamic]u8, content: []u8) {
	test_append_u32(buffer, u32(len(content) + 4))
	append(buffer, ..content)
}

@(private)
test_build_minimal_model :: proc() -> [dynamic]u8 {
	file := make([dynamic]u8)
	append(&file, "MDLX")

	version_content := make([dynamic]u8)
	defer delete(version_content)
	test_append_u32(&version_content, 800)
	test_append_chunk(&file, "VERS", version_content[:])

	model_content := make([dynamic]u8)
	defer delete(model_content)
	test_append_fixed_string(&model_content, "Test Model", 80)
	test_append_fixed_string(&model_content, "", 260)
	test_append_f32(&model_content, 5)
	test_append_f32_values(&model_content, {-1, -2, -3, 1, 2, 3})
	test_append_u32(&model_content, 150)
	test_append_chunk(&file, "MODL", model_content[:])

	sequence_content := make([dynamic]u8)
	defer delete(sequence_content)
	test_append_fixed_string(&sequence_content, "Stand", 80)
	test_append_u32(&sequence_content, 0)
	test_append_u32(&sequence_content, 1000)
	test_append_f32(&sequence_content, 270)
	test_append_u32(&sequence_content, 0)
	test_append_f32(&sequence_content, 3)
	test_append_u32(&sequence_content, 0)
	test_append_f32(&sequence_content, 42.5)
	test_append_f32_values(&sequence_content, {-1, -1, -1, 1, 1, 1})
	test_append_chunk(&file, "SEQS", sequence_content[:])

	global_content := make([dynamic]u8)
	defer delete(global_content)
	test_append_u32(&global_content, 1500)
	test_append_u32(&global_content, 2500)
	test_append_chunk(&file, "GLBS", global_content[:])

	texture_content := make([dynamic]u8)
	defer delete(texture_content)
	test_append_u32(&texture_content, 1)
	test_append_fixed_string(&texture_content, "Textures\\test.blp", 260)
	test_append_u32(&texture_content, 3)
	test_append_chunk(&file, "TEXS", texture_content[:])

	// One material with one layer carrying a linear KMTA alpha track.
	layer_body := make([dynamic]u8)
	defer delete(layer_body)
	test_append_u32(&layer_body, 2) // filter mode: blend
	test_append_u32(&layer_body, 1) // shading flags: unshaded
	test_append_u32(&layer_body, 0) // texture id
	test_append_u32(&layer_body, NO_ID) // texture animation id
	test_append_u32(&layer_body, 0) // coordinate id
	test_append_f32(&layer_body, 0.75)
	append(&layer_body, "KMTA")
	test_append_u32(&layer_body, 2) // key count
	test_append_u32(&layer_body, 1) // linear
	test_append_u32(&layer_body, NO_ID)
	test_append_u32(&layer_body, 0)
	test_append_f32(&layer_body, 1)
	test_append_u32(&layer_body, 1000)
	test_append_f32(&layer_body, 0.5)

	material_body := make([dynamic]u8)
	defer delete(material_body)
	test_append_u32(&material_body, 20) // priority plane
	test_append_u32(&material_body, 1) // flags
	append(&material_body, "LAYS")
	test_append_u32(&material_body, 1)
	test_append_sized_item(&material_body, layer_body[:])

	material_content := make([dynamic]u8)
	defer delete(material_content)
	test_append_sized_item(&material_content, material_body[:])
	test_append_chunk(&file, "MTLS", material_content[:])

	// One triangle geoset.
	geoset_body := make([dynamic]u8)
	defer delete(geoset_body)
	append(&geoset_body, "VRTX")
	test_append_u32(&geoset_body, 3)
	test_append_f32_values(&geoset_body, {0, 0, 0, 1, 0, 0, 0, 1, 0})
	append(&geoset_body, "NRMS")
	test_append_u32(&geoset_body, 3)
	test_append_f32_values(&geoset_body, {0, 0, 1, 0, 0, 1, 0, 0, 1})
	append(&geoset_body, "PTYP")
	test_append_u32(&geoset_body, 1)
	test_append_u32(&geoset_body, 4) // triangles
	append(&geoset_body, "PCNT")
	test_append_u32(&geoset_body, 1)
	test_append_u32(&geoset_body, 3)
	append(&geoset_body, "PVTX")
	test_append_u32(&geoset_body, 3)
	append(&geoset_body, 0, 0, 1, 0, 2, 0) // u16 indices 0, 1, 2
	append(&geoset_body, "GNDX")
	test_append_u32(&geoset_body, 3)
	append(&geoset_body, 0, 0, 0)
	append(&geoset_body, "MTGC")
	test_append_u32(&geoset_body, 1)
	test_append_u32(&geoset_body, 1)
	append(&geoset_body, "MATS")
	test_append_u32(&geoset_body, 1)
	test_append_u32(&geoset_body, 0)
	test_append_u32(&geoset_body, 0) // material id
	test_append_u32(&geoset_body, 0) // selection group
	test_append_u32(&geoset_body, 0) // selection flags
	test_append_f32(&geoset_body, 2)
	test_append_f32_values(&geoset_body, {0, 0, 0, 1, 1, 0})
	test_append_u32(&geoset_body, 1) // sequence extent count
	test_append_f32(&geoset_body, 2)
	test_append_f32_values(&geoset_body, {0, 0, 0, 1, 1, 0})
	append(&geoset_body, "UVAS")
	test_append_u32(&geoset_body, 1)
	append(&geoset_body, "UVBS")
	test_append_u32(&geoset_body, 3)
	test_append_f32_values(&geoset_body, {0, 0, 1, 0, 0, 1})

	geoset_content := make([dynamic]u8)
	defer delete(geoset_content)
	test_append_sized_item(&geoset_content, geoset_body[:])
	test_append_chunk(&file, "GEOS", geoset_content[:])

	// Unknown chunk in the middle; must be skipped by size.
	unknown_content := make([dynamic]u8)
	defer delete(unknown_content)
	append(&unknown_content, 1, 2, 3, 4, 5, 6, 7)
	test_append_chunk(&file, "XXXX", unknown_content[:])

	// One bone whose node carries a Hermite KGTR track.
	node_body := make([dynamic]u8)
	defer delete(node_body)
	test_append_fixed_string(&node_body, "Root", 80)
	test_append_u32(&node_body, 0) // object id
	test_append_u32(&node_body, NO_ID) // parent id
	test_append_u32(&node_body, 0x100) // bone flag
	append(&node_body, "KGTR")
	test_append_u32(&node_body, 1)
	test_append_u32(&node_body, 2) // hermite
	test_append_u32(&node_body, NO_ID)
	test_append_u32(&node_body, 0)
	test_append_f32_values(&node_body, {1, 2, 3}) // value
	test_append_f32_values(&node_body, {0, 0, 0}) // in tangent
	test_append_f32_values(&node_body, {0.5, 0.5, 0.5}) // out tangent

	bone_content := make([dynamic]u8)
	defer delete(bone_content)
	test_append_sized_item(&bone_content, node_body[:])
	test_append_u32(&bone_content, 0) // geoset id
	test_append_u32(&bone_content, NO_ID) // geoset animation id
	test_append_chunk(&file, "BONE", bone_content[:])

	pivot_content := make([dynamic]u8)
	defer delete(pivot_content)
	test_append_f32_values(&pivot_content, {0.5, 1.5, 2.5})
	test_append_chunk(&file, "PIVT", pivot_content[:])

	return file
}

@(test)
minimal_model_decodes :: proc(t: ^testing.T) {
	file := test_build_minimal_model()
	defer delete(file)

	model, error := parse(file[:])
	defer destroy(&model)
	testing.expect_value(t, error, Error.None)

	testing.expect_value(t, model.version, 800)
	testing.expect_value(t, model.name, "Test Model")
	testing.expect_value(t, model.animation_file_name, "")
	testing.expect_value(t, model.extent.bounds_radius, 5)
	testing.expect_value(t, model.extent.minimum_extent, [3]f32{-1, -2, -3})
	testing.expect_value(t, model.extent.maximum_extent, [3]f32{1, 2, 3})
	testing.expect_value(t, model.blend_time, 150)

	testing.expect_value(t, len(model.sequences), 1)
	sequence := model.sequences[0]
	testing.expect_value(t, sequence.name, "Stand")
	testing.expect_value(t, sequence.interval_start, 0)
	testing.expect_value(t, sequence.interval_end, 1000)
	testing.expect_value(t, sequence.move_speed, 270)
	testing.expect_value(t, sequence.rarity, 3)
	testing.expect_value(t, sequence.extent.bounds_radius, 42.5)

	testing.expect_value(t, len(model.global_sequences), 2)
	testing.expect_value(t, model.global_sequences[0], 1500)
	testing.expect_value(t, model.global_sequences[1], 2500)

	testing.expect_value(t, len(model.textures), 1)
	testing.expect_value(t, model.textures[0].replaceable_id, 1)
	testing.expect_value(t, model.textures[0].file_name, "Textures\\test.blp")
	testing.expect_value(t, model.textures[0].flags, 3)

	testing.expect_value(t, len(model.materials), 1)
	material := model.materials[0]
	testing.expect_value(t, material.priority_plane, 20)
	testing.expect_value(t, material.flags, 1)
	testing.expect_value(t, len(material.layers), 1)
	layer := material.layers[0]
	testing.expect_value(t, layer.filter_mode, 2)
	testing.expect_value(t, layer.shading_flags, 1)
	testing.expect_value(t, layer.texture_animation_id, NO_ID)
	testing.expect_value(t, layer.alpha, 0.75)
	testing.expect_value(t, layer.alpha_track.interpolation_type, Interpolation_Type.Linear)
	testing.expect_value(t, layer.alpha_track.global_sequence_id, NO_ID)
	testing.expect_value(t, len(layer.alpha_track.keys), 2)
	testing.expect_value(t, layer.alpha_track.keys[0].time, 0)
	testing.expect_value(t, layer.alpha_track.keys[0].value, 1)
	testing.expect_value(t, layer.alpha_track.keys[1].time, 1000)
	testing.expect_value(t, layer.alpha_track.keys[1].value, 0.5)

	testing.expect_value(t, len(model.geosets), 1)
	geoset := model.geosets[0]
	testing.expect_value(t, len(geoset.vertices), 3)
	testing.expect_value(t, geoset.vertices[1], [3]f32{1, 0, 0})
	testing.expect_value(t, geoset.normals[2], [3]f32{0, 0, 1})
	testing.expect_value(t, len(geoset.face_type_groups), 1)
	testing.expect_value(t, geoset.face_type_groups[0], 4)
	testing.expect_value(t, len(geoset.face_group_index_counts), 1)
	testing.expect_value(t, geoset.face_group_index_counts[0], 3)
	testing.expect_value(t, len(geoset.face_indices), 3)
	testing.expect_value(t, geoset.face_indices[2], 2)
	testing.expect_value(t, len(geoset.vertex_groups), 3)
	testing.expect_value(t, len(geoset.matrix_group_sizes), 1)
	testing.expect_value(t, len(geoset.matrix_indices), 1)
	testing.expect_value(t, geoset.extent.bounds_radius, 2)
	testing.expect_value(t, len(geoset.sequence_extents), 1)
	testing.expect_value(t, geoset.sequence_extents[0].bounds_radius, 2)
	testing.expect_value(t, len(geoset.texture_coordinate_sets), 1)
	testing.expect_value(t, len(geoset.texture_coordinate_sets[0]), 3)
	testing.expect_value(t, geoset.texture_coordinate_sets[0][1], [2]f32{1, 0})

	testing.expect_value(t, len(model.bones), 1)
	bone := model.bones[0]
	testing.expect_value(t, bone.node.name, "Root")
	testing.expect_value(t, bone.node.parent_id, NO_ID)
	testing.expect_value(t, bone.node.flags, 0x100)
	testing.expect_value(t, bone.node.translation.interpolation_type, Interpolation_Type.Hermite)
	testing.expect_value(t, len(bone.node.translation.keys), 1)
	testing.expect_value(t, bone.node.translation.keys[0].value, [3]f32{1, 2, 3})
	testing.expect_value(t, bone.node.translation.keys[0].out_tangent, [3]f32{0.5, 0.5, 0.5})
	testing.expect_value(t, bone.geoset_id, 0)
	testing.expect_value(t, bone.geoset_animation_id, NO_ID)

	testing.expect_value(t, len(model.pivot_points), 1)
	testing.expect_value(t, model.pivot_points[0], [3]f32{0.5, 1.5, 2.5})
}

@(test)
empty_data_fails :: proc(t: ^testing.T) {
	model, error := parse({})
	testing.expect_value(t, error, Error.Invalid_Header)
	testing.expect_value(t, len(model.sequences), 0)
}

@(test)
truncated_magic_fails :: proc(t: ^testing.T) {
	data := [?]u8{'M', 'D', 'L'}
	_, error := parse(data[:])
	testing.expect_value(t, error, Error.Invalid_Header)
}

@(test)
bad_magic_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLY")
	version_content := make([dynamic]u8)
	defer delete(version_content)
	test_append_u32(&version_content, 800)
	test_append_chunk(&file, "VERS", version_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Invalid_Header)
}

@(test)
wrong_version_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	version_content := make([dynamic]u8)
	defer delete(version_content)
	test_append_u32(&version_content, 900)
	test_append_chunk(&file, "VERS", version_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Unsupported_Version)
}

@(test)
chunk_size_overrun_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	append(&file, "SEQS")
	test_append_u32(&file, 100) // only 10 content bytes follow
	for index in 0 ..< 10 {
		append(&file, u8(index))
	}

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
truncated_chunk_header_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	append(&file, "SEQS")
	append(&file, 12) // size field cut short

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
vertex_count_overrun_fails :: proc(t: ^testing.T) {
	// A VRTX count far larger than the remaining bytes must be rejected
	// before any allocation happens.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	geoset_body := make([dynamic]u8)
	defer delete(geoset_body)
	append(&geoset_body, "VRTX")
	test_append_u32(&geoset_body, 0x0FFF_FFFF)
	geoset_content := make([dynamic]u8)
	defer delete(geoset_content)
	test_append_sized_item(&geoset_content, geoset_body[:])
	test_append_chunk(&file, "GEOS", geoset_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
track_count_overrun_fails :: proc(t: ^testing.T) {
	// A KMTA key count that overruns the layer must be rejected before
	// any allocation happens.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	layer_body := make([dynamic]u8)
	defer delete(layer_body)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, NO_ID)
	test_append_u32(&layer_body, 0)
	test_append_f32(&layer_body, 1)
	append(&layer_body, "KMTA")
	test_append_u32(&layer_body, 1000) // no key data follows
	test_append_u32(&layer_body, 1)
	test_append_u32(&layer_body, NO_ID)
	material_body := make([dynamic]u8)
	defer delete(material_body)
	test_append_u32(&material_body, 0)
	test_append_u32(&material_body, 0)
	append(&material_body, "LAYS")
	test_append_u32(&material_body, 1)
	test_append_sized_item(&material_body, layer_body[:])
	material_content := make([dynamic]u8)
	defer delete(material_content)
	test_append_sized_item(&material_content, material_body[:])
	test_append_chunk(&file, "MTLS", material_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
node_size_overrun_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	bone_content := make([dynamic]u8)
	defer delete(bone_content)
	test_append_u32(&bone_content, 200) // node inclusive size beyond the chunk
	test_append_fixed_string(&bone_content, "Broken", 80)
	test_append_chunk(&file, "BONE", bone_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
sequence_chunk_truncated_item_fails :: proc(t: ^testing.T) {
	// 100 bytes cannot hold a 132-byte sequence; the name still parses,
	// so this exercises the string cleanup on the error path.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	sequence_content := make([dynamic]u8)
	defer delete(sequence_content)
	for _ in 0 ..< 100 {
		append(&sequence_content, 'A')
	}
	test_append_chunk(&file, "SEQS", sequence_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
duplicate_chunk_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	pivot_content := make([dynamic]u8)
	defer delete(pivot_content)
	test_append_f32_values(&pivot_content, {0.5, 1.5, 2.5})
	test_append_chunk(&file, "PIVT", pivot_content[:])
	test_append_chunk(&file, "PIVT", pivot_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
empty_then_repeated_chunk_fails :: proc(t: ^testing.T) {
	// Regression: repeat detection used to key on the first chunk's
	// parsed data being non-nil, so an empty first chunk let a repeat
	// through. The typed-tag rule must hold regardless of content.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	test_append_chunk(&file, "PIVT", {})
	pivot_content := make([dynamic]u8)
	defer delete(pivot_content)
	test_append_f32_values(&pivot_content, {0.5, 1.5, 2.5})
	test_append_chunk(&file, "PIVT", pivot_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
unknown_chunk_repeats_are_tolerated :: proc(t: ^testing.T) {
	// Skipping an unknown chunk is free of side effects, so repeats of
	// unknown tags stay tolerated; only typed tags are single-use.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	version_content := make([dynamic]u8)
	defer delete(version_content)
	test_append_u32(&version_content, 800)
	test_append_chunk(&file, "VERS", version_content[:])
	unknown_content := make([dynamic]u8)
	defer delete(unknown_content)
	append(&unknown_content, 1, 2, 3)
	test_append_chunk(&file, "XXXX", unknown_content[:])
	test_append_chunk(&file, "XXXX", unknown_content[:])

	model, error := parse(file[:])
	defer destroy(&model)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, model.version, 800)
}

@(test)
track_interpolation_above_bezier_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	layer_body := make([dynamic]u8)
	defer delete(layer_body)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, NO_ID)
	test_append_u32(&layer_body, 0)
	test_append_f32(&layer_body, 1)
	append(&layer_body, "KMTA")
	test_append_u32(&layer_body, 0) // key count
	test_append_u32(&layer_body, 4) // no such interpolation type
	test_append_u32(&layer_body, NO_ID)
	material_body := make([dynamic]u8)
	defer delete(material_body)
	test_append_u32(&material_body, 0)
	test_append_u32(&material_body, 0)
	append(&material_body, "LAYS")
	test_append_u32(&material_body, 1)
	test_append_sized_item(&material_body, layer_body[:])
	material_content := make([dynamic]u8)
	defer delete(material_content)
	test_append_sized_item(&material_content, material_body[:])
	test_append_chunk(&file, "MTLS", material_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
unknown_layer_sub_tag_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	layer_body := make([dynamic]u8)
	defer delete(layer_body)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, 0)
	test_append_u32(&layer_body, NO_ID)
	test_append_u32(&layer_body, 0)
	test_append_f32(&layer_body, 1)
	append(&layer_body, "ZZZZ")
	test_append_u32(&layer_body, 0)
	material_body := make([dynamic]u8)
	defer delete(material_body)
	test_append_u32(&material_body, 0)
	test_append_u32(&material_body, 0)
	append(&material_body, "LAYS")
	test_append_u32(&material_body, 1)
	test_append_sized_item(&material_body, layer_body[:])
	material_content := make([dynamic]u8)
	defer delete(material_content)
	test_append_sized_item(&material_content, material_body[:])
	test_append_chunk(&file, "MTLS", material_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
duplicated_node_track_keeps_last :: proc(t: ^testing.T) {
	// A duplicated track tag within one node does not occur in the
	// corpus; the parser keeps the last set and frees the earlier one.
	// The runner's memory tracking pins the leak-freeness.
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	node_body := make([dynamic]u8)
	defer delete(node_body)
	test_append_fixed_string(&node_body, "Root", 80)
	test_append_u32(&node_body, 0)
	test_append_u32(&node_body, NO_ID)
	test_append_u32(&node_body, 0x100)
	append(&node_body, "KGTR")
	test_append_u32(&node_body, 1)
	test_append_u32(&node_body, 1) // linear
	test_append_u32(&node_body, NO_ID)
	test_append_u32(&node_body, 0)
	test_append_f32_values(&node_body, {1, 1, 1})
	append(&node_body, "KGTR")
	test_append_u32(&node_body, 1)
	test_append_u32(&node_body, 1) // linear
	test_append_u32(&node_body, NO_ID)
	test_append_u32(&node_body, 500)
	test_append_f32_values(&node_body, {9, 9, 9})
	bone_content := make([dynamic]u8)
	defer delete(bone_content)
	test_append_sized_item(&bone_content, node_body[:])
	test_append_u32(&bone_content, 0)
	test_append_u32(&bone_content, NO_ID)
	test_append_chunk(&file, "BONE", bone_content[:])

	model, error := parse(file[:])
	defer destroy(&model)
	testing.expect_value(t, error, Error.None)
	testing.expect_value(t, len(model.bones), 1)
	testing.expect_value(t, len(model.bones[0].node.translation.keys), 1)
	testing.expect_value(t, model.bones[0].node.translation.keys[0].time, 500)
	testing.expect_value(t, model.bones[0].node.translation.keys[0].value, [3]f32{9, 9, 9})
}

@(test)
node_size_below_minimum_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	bone_content := make([dynamic]u8)
	defer delete(bone_content)
	test_append_u32(&bone_content, 10) // below the 96-byte node minimum
	test_append_fixed_string(&bone_content, "Broken", 80)
	test_append_chunk(&file, "BONE", bone_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}

@(test)
collision_shape_unknown_type_fails :: proc(t: ^testing.T) {
	file := make([dynamic]u8)
	defer delete(file)
	append(&file, "MDLX")
	node_body := make([dynamic]u8)
	defer delete(node_body)
	test_append_fixed_string(&node_body, "Shape", 80)
	test_append_u32(&node_body, 0)
	test_append_u32(&node_body, NO_ID)
	test_append_u32(&node_body, 0x2000)
	shape_content := make([dynamic]u8)
	defer delete(shape_content)
	test_append_sized_item(&shape_content, node_body[:])
	test_append_u32(&shape_content, 7) // no such shape type
	test_append_f32_values(&shape_content, {0, 0, 0, 1, 1, 1})
	test_append_chunk(&file, "CLID", shape_content[:])

	_, error := parse(file[:])
	testing.expect_value(t, error, Error.Corrupt_Chunk)
}
