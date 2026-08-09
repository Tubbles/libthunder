package mdx

// Typed data carriers for every chunk that occurs in the 1.29.2 corpus.
// Field order mirrors the file layout (Magos's MDX spec, corrected against
// the corpus where the two disagree; deviations are commented at the parse
// sites in mdx_chunks.odin). Color vectors keep the stored order, which is
// blue, green, red. IDs use NO_ID (0xFFFFFFFF) for "none".

NO_ID: u32 : 0xFFFF_FFFF

Interpolation_Type :: enum u32 {
	None    = 0,
	Linear  = 1,
	Hermite = 2,
	Bezier  = 3,
}

// One keyframe of an animation track. Tangents are meaningful only for
// Hermite and Bezier interpolation; otherwise they are zero.
Track_Key :: struct($Value: typeid) {
	time:        i32,
	value:       Value,
	in_tangent:  Value,
	out_tangent: Value,
}

Track_Set :: struct($Value: typeid) {
	interpolation_type: Interpolation_Type,
	global_sequence_id: u32,
	keys:               []Track_Key(Value),
}

Extent :: struct {
	bounds_radius:  f32,
	minimum_extent: [3]f32,
	maximum_extent: [3]f32,
}

// Shared header of every animated object (bones, helpers, lights,
// attachments, emitters, event objects, collision shapes).
Node :: struct {
	name:        string,
	object_id:   u32,
	parent_id:   u32,
	flags:       u32,
	translation: Track_Set([3]f32), // KGTR
	rotation:    Track_Set([4]f32), // KGRT
	scaling:     Track_Set([3]f32), // KGSC
}

Sequence :: struct {
	name:           string,
	interval_start: u32,
	interval_end:   u32,
	move_speed:     f32,
	flags:          u32, // 0 looping, 1 non-looping
	rarity:         f32,
	sync_point:     u32,
	extent:         Extent,
}

Texture :: struct {
	replaceable_id: u32,
	file_name:      string,
	flags:          u32, // 1 wrap width, 2 wrap height
}

Texture_Animation :: struct {
	translation: Track_Set([3]f32), // KTAT
	rotation:    Track_Set([4]f32), // KTAR
	scaling:     Track_Set([3]f32), // KTAS
}

Layer :: struct {
	filter_mode:          u32, // 0 none, 1 transparent, 2 blend, 3 additive, 4 add alpha, 5 modulate, 6 modulate 2x
	shading_flags:        u32,
	texture_id:           u32,
	texture_animation_id: u32,
	coordinate_id:        u32,
	alpha:                f32,
	alpha_track:          Track_Set(f32), // KMTA
	texture_id_track:     Track_Set(u32), // KMTF
}

Material :: struct {
	priority_plane: u32,
	flags:          u32,
	layers:         []Layer,
}

Geoset :: struct {
	vertices:                [][3]f32, // VRTX
	normals:                 [][3]f32, // NRMS
	face_type_groups:        []u32, // PTYP; the corpus only contains 4 (triangles)
	face_group_index_counts: []u32, // PCNT
	face_indices:            []u16, // PVTX
	vertex_groups:           []u8, // GNDX
	matrix_group_sizes:      []u32, // MTGC
	matrix_indices:          []u32, // MATS
	material_id:             u32,
	selection_group:         u32,
	selection_flags:         u32, // 4 unselectable
	extent:                  Extent,
	sequence_extents:        []Extent, // one per sequence
	texture_coordinate_sets: [][][2]f32, // UVAS/UVBS
}

Geoset_Animation :: struct {
	alpha:       f32,
	flags:       u32, // 1 drop shadow, 2 color
	color:       [3]f32,
	geoset_id:   u32,
	alpha_track: Track_Set(f32), // KGAO
	color_track: Track_Set([3]f32), // KGAC
}

Bone :: struct {
	node:                Node,
	geoset_id:           u32,
	geoset_animation_id: u32,
}

Light :: struct {
	node:                    Node,
	light_type:              u32, // 0 omnidirectional, 1 directional, 2 ambient
	attenuation_start:       f32,
	attenuation_end:         f32,
	color:                   [3]f32,
	intensity:               f32,
	ambient_color:           [3]f32,
	ambient_intensity:       f32,
	visibility_track:        Track_Set(f32), // KLAV
	color_track:             Track_Set([3]f32), // KLAC
	intensity_track:         Track_Set(f32), // KLAI
	ambient_color_track:     Track_Set([3]f32), // KLBC
	ambient_intensity_track: Track_Set(f32), // KLBI
}

Helper :: struct {
	node: Node,
}

Attachment :: struct {
	node:             Node,
	path:             string,
	attachment_id:    u32,
	visibility_track: Track_Set(f32), // KATV
}

Particle_Emitter :: struct {
	node:                  Node,
	emission_rate:         f32,
	gravity:               f32,
	longitude:             f32,
	latitude:              f32,
	spawn_model_file_name: string,
	life_span:             f32,
	initial_velocity:      f32,
	visibility_track:      Track_Set(f32), // KPEV
}

Particle_Emitter_2 :: struct {
	node:                Node,
	speed:               f32,
	variation:           f32,
	latitude:            f32,
	gravity:             f32,
	life_span:           f32,
	emission_rate:       f32,
	length:              f32,
	width:               f32,
	filter_mode:         u32, // 0 blend, 1 additive, 2 modulate, 3 modulate 2x, 4 alpha key
	rows:                u32,
	columns:             u32,
	head_or_tail:        u32, // 0 head, 1 tail, 2 both
	tail_length:         f32,
	time:                f32,
	segment_colors:      [3][3]f32,
	segment_alphas:      [3]u8,
	segment_scaling:     [3]f32,
	head_interval:       [3]u32, // start, end, repeat
	head_decay_interval: [3]u32,
	tail_interval:       [3]u32,
	tail_decay_interval: [3]u32,
	texture_id:          u32,
	squirt:              u32,
	priority_plane:      u32,
	replaceable_id:      u32,
	visibility_track:    Track_Set(f32), // KP2V
	emission_rate_track: Track_Set(f32), // KP2E
	width_track:         Track_Set(f32), // KP2W
	length_track:        Track_Set(f32), // KP2N
	speed_track:         Track_Set(f32), // KP2S
	latitude_track:      Track_Set(f32), // KP2L
}

Ribbon_Emitter :: struct {
	node:               Node,
	height_above:       f32,
	height_below:       f32,
	alpha:              f32,
	color:              [3]f32,
	life_span:          f32,
	texture_slot:       u32,
	emission_rate:      u32,
	rows:               u32,
	columns:            u32,
	material_id:        u32,
	gravity:            f32,
	visibility_track:   Track_Set(f32), // KRVS
	height_above_track: Track_Set(f32), // KRHA
	height_below_track: Track_Set(f32), // KRHB
}

Event_Object :: struct {
	node:               Node,
	global_sequence_id: u32,
	times:              []i32, // KEVT
}

Camera :: struct {
	name:                string,
	position:            [3]f32,
	field_of_view:       f32,
	far_clipping_plane:  f32,
	near_clipping_plane: f32,
	target_position:     [3]f32,
	position_track:      Track_Set([3]f32), // KCTR
	target_track:        Track_Set([3]f32), // KTTR
	rotation_track:      Track_Set(f32), // KCRL
}

Collision_Shape :: struct {
	node:          Node,
	shape_type:    u32, // 0 box (two corners), 2 sphere (center and radius)
	vertices:      [2][3]f32,
	vertex_count:  int,
	bounds_radius: f32, // spheres only
}
