shader_type canvas_item;

// Logout effect: fade out with pixelation
uniform float progress: hint_range(0.0, 1.0) = 0.0;
uniform float pixelation_scale: hint_range(1.0, 20.0) = 10.0;

void fragment() {
	// Get base texture color
	vec2 uv = UV;
	
	// Apply pixelation effect that increases with progress
	float pixel_size = mix(1.0, pixelation_scale, progress);
	vec2 pixelated_uv = floor(uv * TEXTURE_PIXEL_SIZE.xy / pixel_size) * pixel_size / TEXTURE_PIXEL_SIZE.xy;
	
	vec4 col = texture(TEXTURE, pixelated_uv);
	
	// Fade out
	col.a *= (1.0 - progress);
	
	COLOR = col;
}


