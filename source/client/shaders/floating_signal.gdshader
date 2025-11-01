shader_type canvas_item;

// Floating animation parameters
uniform float float_speed : hint_range(0.0, 5.0) = 1.5;
uniform float float_amplitude : hint_range(0.0, 50.0) = 8.0;
uniform float time_offset : hint_range(0.0, 6.28) = 0.0;

void vertex() {
	float time = TIME + time_offset;
	// Simple sine wave for smooth up and down movement
	float offset_y = sin(time * float_speed) * float_amplitude;
	VERTEX.y += offset_y;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
