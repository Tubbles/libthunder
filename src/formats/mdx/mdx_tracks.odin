package mdx

// Generic keyframe track parsing. Every K*** sub-chunk in the format
// shares one layout: u32 key count, u32 interpolation type, u32 global
// sequence id, then per key an i32 time and a value, plus an in-tangent
// and out-tangent of the same value type when the interpolation is
// Hermite or Bezier. The value type varies per tag (f32, [3]f32,
// [4]f32, or u32 for texture id flips); this parser is instantiated
// per value type. KEVT (event object times) is the one exception and
// is parsed in parse_event_object.

import "base:runtime"

@(private)
parse_track_set :: proc(reader: ^Reader, track_set: ^Track_Set($Value), allocator: runtime.Allocator) -> Error {
	key_count, key_count_ok := read_u32(reader)
	interpolation_raw, interpolation_ok := read_u32(reader)
	global_sequence_id, global_sequence_ok := read_u32(reader)
	if !key_count_ok || !interpolation_ok || !global_sequence_ok {
		return .Corrupt_Chunk
	}
	if interpolation_raw > u32(Interpolation_Type.Bezier) {
		return .Corrupt_Chunk
	}
	has_tangents := interpolation_raw >= u32(Interpolation_Type.Hermite)
	bytes_per_key := 4 + size_of(Value) * (3 if has_tangents else 1)
	if i64(key_count) * i64(bytes_per_key) > i64(reader_remaining(reader)) {
		return .Corrupt_Chunk
	}
	// A duplicated track tag within one object does not occur in the
	// corpus; keep the last set and free the earlier one.
	delete(track_set.keys, allocator)
	track_set.interpolation_type = Interpolation_Type(interpolation_raw)
	track_set.global_sequence_id = global_sequence_id
	track_set.keys = make([]Track_Key(Value), int(key_count), allocator)
	for &key in track_set.keys {
		if !read_value(reader, &key.time) || !read_value(reader, &key.value) {
			return .Corrupt_Chunk
		}
		if has_tangents {
			if !read_value(reader, &key.in_tangent) || !read_value(reader, &key.out_tangent) {
				return .Corrupt_Chunk
			}
		}
	}
	return .None
}

@(private)
destroy_track_set :: proc(track_set: ^Track_Set($Value), allocator: runtime.Allocator) {
	delete(track_set.keys, allocator)
	track_set.keys = nil
}
