package thunder

import "core:testing"

@(test)
version_constants_are_set :: proc(t: ^testing.T) {
	testing.expect(t, len(VERSION) > 0)
	testing.expect_value(t, TARGET_GAME_PATCH, "1.29b")
}
