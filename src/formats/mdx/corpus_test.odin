package mdx

import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import mpq "thunder:formats/mpq"

// Reference values below were derived with an independent Python
// struct-based reader over the same corpus files (WI-0009 log,
// 2026-08-09), not from this parser.

@(test)
corpus_footman_decodes :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "Units\\Human\\Footman\\Footman.mdx")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)

	model, parse_error := parse(data)
	defer destroy(&model)
	testing.expect_value(t, parse_error, Error.None)

	testing.expect_value(t, model.version, 800)
	testing.expect_value(t, model.name, "Footman")
	testing.expect_value(t, model.animation_file_name, "")
	testing.expect_value(t, model.blend_time, 150)
	testing.expect_value(t, model.extent.minimum_extent, [3]f32{-90.77249908447266, -64.97200012207031, -43.84939956665039})

	testing.expect_value(t, len(model.sequences), 13)
	testing.expect_value(t, model.sequences[0].name, "Stand - 1")
	testing.expect_value(t, model.sequences[0].interval_start, 167)
	testing.expect_value(t, model.sequences[0].interval_end, 1667)
	testing.expect_value(t, model.sequences[2].name, "Stand Victory")
	testing.expect_value(t, model.sequences[2].extent.bounds_radius, 82.37940216064453)
	testing.expect_value(t, model.sequences[3].rarity, 5)
	testing.expect_value(t, model.sequences[6].name, "Walk")
	testing.expect_value(t, model.sequences[6].move_speed, 215)
	testing.expect_value(t, model.sequences[12].name, "Decay Bone")
	testing.expect_value(t, model.sequences[12].interval_end, 219967)
	testing.expect_value(t, model.sequences[12].flags, 1)

	testing.expect_value(t, len(model.textures), 3)
	testing.expect_value(t, model.textures[0].file_name, "Textures\\Footman.blp")
	testing.expect_value(t, model.textures[1].replaceable_id, 1)
	testing.expect_value(t, model.textures[1].file_name, "")
	testing.expect_value(t, model.textures[2].file_name, "Textures\\gutz.blp")

	testing.expect_value(t, len(model.materials), 3)
	testing.expect_value(t, len(model.materials[0].layers), 1)
	testing.expect_value(t, len(model.materials[1].layers), 2)
	testing.expect_value(t, len(model.materials[2].layers), 1)
	testing.expect_value(t, model.materials[1].layers[0].texture_id, 1)
	testing.expect_value(t, model.materials[1].layers[0].shading_flags, 1)
	blood_layer := model.materials[2].layers[0]
	testing.expect_value(t, blood_layer.texture_id, 2)
	testing.expect_value(t, blood_layer.alpha_track.interpolation_type, Interpolation_Type.Linear)
	testing.expect_value(t, len(blood_layer.alpha_track.keys), 7)
	testing.expect_value(t, blood_layer.alpha_track.keys[0].time, 25000)
	testing.expect_value(t, blood_layer.alpha_track.keys[2].value, 0.9980229735374451)

	testing.expect_value(t, len(model.geosets), 5)
	expected_vertex_counts := [5]int{447, 52, 26, 6, 51}
	expected_index_counts := [5]int{864, 105, 51, 24, 72}
	for geoset, geoset_index in model.geosets {
		testing.expect_value(t, len(geoset.vertices), expected_vertex_counts[geoset_index])
		testing.expect_value(t, len(geoset.normals), expected_vertex_counts[geoset_index])
		testing.expect_value(t, len(geoset.face_indices), expected_index_counts[geoset_index])
		testing.expect_value(t, len(geoset.vertex_groups), expected_vertex_counts[geoset_index])
		testing.expect_value(t, len(geoset.sequence_extents), 13)
		testing.expect_value(t, len(geoset.texture_coordinate_sets), 1)
		testing.expect_value(t, len(geoset.texture_coordinate_sets[0]), expected_vertex_counts[geoset_index])
	}
	first_geoset := model.geosets[0]
	testing.expect_value(t, first_geoset.vertices[0], [3]f32{-6.7494797706604, 16.95639991760254, 1.4789999723434448})
	testing.expect_value(t, first_geoset.texture_coordinate_sets[0][0], [2]f32{0.8798120021820068, 0.9973819851875305})
	testing.expect_value(t, first_geoset.extent.bounds_radius, 114.95500183105469)
	testing.expect_value(t, len(first_geoset.matrix_group_sizes), 35)
	testing.expect_value(t, len(first_geoset.matrix_indices), 54)
	testing.expect_value(t, first_geoset.face_indices[0], 0)
	testing.expect_value(t, first_geoset.face_indices[1], 1)
	testing.expect_value(t, first_geoset.face_indices[2], 2)

	testing.expect_value(t, len(model.geoset_animations), 5)

	testing.expect_value(t, len(model.bones), 25)
	testing.expect_value(t, model.bones[0].node.name, "gutz00")
	testing.expect_value(t, model.bones[0].node.parent_id, NO_ID)
	testing.expect_value(t, model.bones[0].geoset_id, 4)
	testing.expect_value(t, model.bones[1].node.name, "Box04")
	testing.expect_value(t, model.bones[1].node.rotation.interpolation_type, Interpolation_Type.Hermite)
	testing.expect_value(t, len(model.bones[1].node.rotation.keys), 27)
	testing.expect_value(t, model.bones[9].node.name, "handle")
	testing.expect_value(t, len(model.bones[9].node.translation.keys), 6)

	testing.expect_value(t, len(model.helpers), 15)
	testing.expect_value(t, model.helpers[0].node.name, "Bone_Root")
	testing.expect_value(t, model.helpers[0].node.object_id, 25)
	testing.expect_value(t, model.helpers[14].node.name, "Bone_Head")

	testing.expect_value(t, len(model.attachments), 9)
	testing.expect_value(t, model.attachments[0].node.name, "Foot Left Ref ")
	testing.expect_value(t, model.attachments[0].attachment_id, 0)
	testing.expect_value(t, len(model.attachments[0].visibility_track.keys), 3)
	testing.expect_value(t, model.attachments[0].visibility_track.keys[1].time, 85000)
	testing.expect_value(t, model.attachments[0].visibility_track.keys[1].value, 0)
	testing.expect_value(t, model.attachments[8].node.name, "OverHead Ref ")
	testing.expect_value(t, model.attachments[8].attachment_id, 8)

	testing.expect_value(t, len(model.pivot_points), 57)
	testing.expect_value(t, model.pivot_points[0], [3]f32{-48.96950149536133, 7.012199878692627, 7.852729797363281})
	testing.expect_value(t, model.pivot_points[56], [3]f32{3.239419937133789, 0, 22.847400665283203})

	testing.expect_value(t, len(model.event_objects), 6)
	testing.expect_value(t, model.event_objects[0].node.name, "SNDXDFOO")
	testing.expect_value(t, model.event_objects[0].global_sequence_id, NO_ID)
	testing.expect_value(t, len(model.event_objects[0].times), 1)
	testing.expect_value(t, model.event_objects[0].times[0], 21333)
	testing.expect_value(t, len(model.event_objects[2].times), 2)
	testing.expect_value(t, model.event_objects[2].times[1], 20800)

	testing.expect_value(t, len(model.collision_shapes), 2)
	testing.expect_value(t, model.collision_shapes[0].shape_type, 2)
	testing.expect_value(t, model.collision_shapes[0].vertex_count, 1)
	testing.expect_value(t, model.collision_shapes[0].vertices[0], [3]f32{5.257450103759766, 0, 63.22100067138672})
	testing.expect_value(t, model.collision_shapes[0].bounds_radius, 38.07600021362305)
	testing.expect_value(t, model.collision_shapes[1].bounds_radius, 38.07600021362305)
}

@(test)
corpus_centaur_tent_decodes :: proc(t: ^testing.T) {
	archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", "War3.mpq"})
	defer delete(archive_path)
	if !os.exists(archive_path) {
		log.info("corpus absent, skipping")
		return
	}

	archive, open_error := mpq.open(archive_path)
	testing.expect_value(t, open_error, mpq.Error.None)
	defer mpq.close(archive)

	data, read_error := mpq.read_file(archive, "Buildings\\Other\\CentaurTent1\\CentaurTent1.mdx")
	defer delete(data)
	testing.expect_value(t, read_error, mpq.Error.None)

	model, parse_error := parse(data)
	defer destroy(&model)
	testing.expect_value(t, parse_error, Error.None)

	testing.expect_value(t, model.name, "CentaurTent1")
	testing.expect_value(t, len(model.sequences), 3)
	testing.expect_value(t, model.sequences[1].name, "portrait -1")

	testing.expect_value(t, len(model.textures), 8)
	testing.expect_value(t, model.textures[0].replaceable_id, 2)
	testing.expect_value(t, model.textures[6].file_name, "ReplaceableTextures\\Weather\\Clouds8x8.blp")

	testing.expect_value(t, len(model.geosets), 2)
	testing.expect_value(t, len(model.geosets[0].vertices), 4)
	testing.expect_value(t, len(model.geosets[1].vertices), 105)

	testing.expect_value(t, len(model.geoset_animations), 2)
	testing.expect_value(t, model.geoset_animations[0].alpha, 1)
	testing.expect_value(t, model.geoset_animations[1].geoset_id, 1)
	testing.expect_value(t, len(model.geoset_animations[0].alpha_track.keys), 2)
	testing.expect_value(t, model.geoset_animations[0].alpha_track.keys[0].time, 67)
	testing.expect_value(t, model.geoset_animations[0].alpha_track.keys[0].value, 0)

	testing.expect_value(t, len(model.lights), 1)
	light := model.lights[0]
	testing.expect_value(t, light.node.name, "Omni01")
	testing.expect_value(t, light.light_type, 0)
	testing.expect_value(t, light.attenuation_start, 80)
	testing.expect_value(t, light.attenuation_end, 200)
	testing.expect_value(t, light.color, [3]f32{1, 0.9843140244483948, 0.8745099902153015})
	testing.expect_value(t, light.intensity, 17)
	testing.expect_value(t, light.visibility_track.interpolation_type, Interpolation_Type.None)
	testing.expect_value(t, len(light.visibility_track.keys), 5)
	testing.expect_value(t, light.visibility_track.keys[3].time, 65300)
	testing.expect_value(t, light.visibility_track.keys[3].value, 1)

	testing.expect_value(t, len(model.particle_emitters_2), 7)
	debris := model.particle_emitters_2[0]
	testing.expect_value(t, debris.node.name, "SmallBlastDebris")
	testing.expect_value(t, debris.speed, 440)
	testing.expect_value(t, debris.latitude, 55)
	testing.expect_value(t, debris.gravity, 749)
	testing.expect_value(t, debris.life_span, 0.7099999785423279)
	testing.expect_value(t, debris.length, 24)
	testing.expect_value(t, debris.width, 24)
	testing.expect_value(t, debris.filter_mode, 0)
	testing.expect_value(t, debris.rows, 1)
	testing.expect_value(t, debris.columns, 1)
	testing.expect_value(t, debris.head_or_tail, 0)
	testing.expect_value(t, debris.segment_colors[0], [3]f32{1, 0.6823530197143555, 0})
	testing.expect_value(t, debris.segment_alphas, [3]u8{255, 255, 0})
	testing.expect_value(t, debris.segment_scaling, [3]f32{5, 5, 5})
	testing.expect_value(t, debris.texture_id, 2)
	testing.expect_value(t, debris.squirt, 1)

	testing.expect_value(t, len(model.cameras), 1)
	camera := model.cameras[0]
	testing.expect_value(t, camera.name, "Camera01")
	testing.expect_value(t, camera.position, [3]f32{352.6300048828125, -56.037200927734375, 166.1479949951172})
	testing.expect_value(t, camera.field_of_view, 0.7878140211105347)
	testing.expect_value(t, camera.far_clipping_plane, 1000)
	testing.expect_value(t, camera.near_clipping_plane, 8)
	testing.expect_value(t, camera.target_position, [3]f32{-105.26899719238281, -39.199501037597656, 82.6500015258789})

	testing.expect_value(t, len(model.event_objects), 1)
	testing.expect_value(t, model.event_objects[0].node.name, "SNDxDOLS")
	testing.expect_value(t, model.event_objects[0].times[0], 65033)
}

// Parses every listfile .mdx in War3.mpq and War3x.mpq. Gated like the
// other corpus sweeps because MPQ extraction dominates the runtime.
@(test)
corpus_all_mdx_parse :: proc(t: ^testing.T) {
	sweep_flag := os.get_env("THUNDER_CORPUS_SWEEP", context.allocator)
	defer delete(sweep_flag)
	if sweep_flag != "1" {
		log.info("THUNDER_CORPUS_SWEEP not set, skipping")
		return
	}

	archive_names := [?]string{"War3.mpq", "War3x.mpq"}
	for archive_name in archive_names {
		archive_path, _ := filepath.join({#directory, "..", "..", "..", "data", "Warcraft III", archive_name})
		defer delete(archive_path)
		if !os.exists(archive_path) {
			continue
		}

		archive, open_error := mpq.open(archive_path)
		testing.expect_value(t, open_error, mpq.Error.None)
		defer mpq.close(archive)

		listfile, listfile_error := mpq.read_file(archive, "(listfile)")
		defer delete(listfile)
		testing.expect_value(t, listfile_error, mpq.Error.None)

		parsed_count := 0
		failed_count := 0
		listfile_text := string(listfile)
		for line in strings.split_lines_iterator(&listfile_text) {
			file_name := strings.trim_space(line)
			lowered := strings.to_lower(file_name)
			is_mdx := strings.has_suffix(lowered, ".mdx")
			delete(lowered)
			if !is_mdx {
				continue
			}

			data, read_error := mpq.read_file(archive, file_name)
			if read_error != .None {
				failed_count += 1
				delete(data)
				continue
			}
			model, parse_error := parse(data)
			if parse_error == .None {
				parsed_count += 1
			} else {
				failed_count += 1
				if failed_count <= 20 {
					log.infof("%s: %v: %s", archive_name, parse_error, file_name)
				}
			}
			destroy(&model)
			delete(data)
		}
		log.infof("%s: parsed %d MDX models, failed %d", archive_name, parsed_count, failed_count)
		testing.expect_value(t, failed_count, 0)
		testing.expect(t, parsed_count > 0, "sweep parsed nothing")
	}
}
