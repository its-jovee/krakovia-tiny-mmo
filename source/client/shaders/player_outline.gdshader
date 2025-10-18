shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_thickness = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * line_thickness;
	
	float a = col.a;
	
	// Sample neighboring pixels
	a = max(a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
	
	// Create outline effect
	vec4 final_color = col;
	if (col.a < 0.1 && a > 0.1) {
		final_color = line_color;
	}
	
	COLOR = final_color;
}
