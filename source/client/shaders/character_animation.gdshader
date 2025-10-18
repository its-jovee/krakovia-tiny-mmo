shader_type canvas_item;

// Animation parameters
uniform float breathing_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float breathing_speed : hint_range(0.0, 5.0) = 2.5;
uniform float squash_stretch_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float squash_stretch_speed : hint_range(0.0, 10.0) = 4.0;

// Animation state (0 = idle, 1 = run/harvest, 2 = sitting)
uniform int animation_state : hint_range(0, 2) = 0;

// Time parameter (randomized per character to avoid sync)
uniform float time_offset = 0.0;

void vertex() {
	float time = TIME + time_offset;
	vec2 pivot = vec2(0.5, 1.0); // Pivot at bottom center
	vec2 uv_centered = UV - pivot;
	
	if (animation_state == 0 || animation_state == 2) {
		// BREATHING ANIMATION (Idle & Sitting)
		// More expressive and frequent breathing
		float breath = sin(time * breathing_speed) * breathing_intensity * 0.035;
		float scale_y = 1.0 + breath;
		float scale_x = 1.0 - breath * 0.3; // Less horizontal change, more vertical emphasis
		
		uv_centered.y *= scale_y;
		uv_centered.x *= scale_x;
	}
	else if (animation_state == 1) {
		// SQUASH & STRETCH (Walking/Running/Harvesting)
		// More subtle, vertically-focused bounce
		float bounce = abs(sin(time * squash_stretch_speed));
		
		// Subtle vertical squash/stretch, minimal horizontal
		float squash_amount = mix(1.0 - squash_stretch_intensity, 1.0 + squash_stretch_intensity * 0.3, bounce);
		float stretch_amount = mix(1.0 + squash_stretch_intensity * 0.2, 1.0 - squash_stretch_intensity * 0.2, bounce);
		
		uv_centered.y *= squash_amount;
		uv_centered.x *= stretch_amount;
	}
	
	UV = uv_centered + pivot;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
