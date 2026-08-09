package blp

// TEMPORARY: replaced by the real JPEG-content path once the baseline
// JPEG decoder package lands (WI-0008 log). Delete on integration.

import "base:runtime"

@(private)
decode_jpeg_mip :: proc(data: []u8, texture_info: Info, mip_data: []u8, width: int, height: int, allocator: runtime.Allocator) -> (pixels: []u8, error: Error) {
	_ = data
	_ = texture_info
	_ = mip_data
	_ = width
	_ = height
	_ = allocator
	return nil, .Unsupported_Format
}
