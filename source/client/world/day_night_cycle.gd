class_name DayNightCycle
extends Node
## Client-side day/night cycle visual controller.
## Smoothly transitions CanvasModulate color and shadow direction based on server time.

## Color palette for different times of day
const DAWN_COLOR = Color(0.90, 0.78, 0.62)     # Warm orange sunrise
const DAY_COLOR = Color(0.88, 0.87, 0.82)      # Soft warm daylight
const DUSK_COLOR = Color(0.90, 0.65, 0.50)     # Orange/red sunset
const EVENING_COLOR = Color(0.6, 0.55, 0.75)   # Purple twilight
const NIGHT_COLOR = Color(0.4, 0.45, 0.7)      # Cool blue night
const MIDNIGHT_COLOR = Color(0.25, 0.28, 0.5)  # Deep blue midnight
const PRE_DAWN_COLOR = Color(0.5, 0.4, 0.6)    # Purple pre-dawn

## Light colors for sun/moon
const SUN_COLOR = Color(1.0, 0.95, 0.85)       # Warm sunlight
const DAWN_LIGHT_COLOR = Color(1.0, 0.7, 0.5)  # Orange dawn light
const DUSK_LIGHT_COLOR = Color(1.0, 0.6, 0.4)  # Red-orange dusk light
const MOON_COLOR = Color(0.6, 0.65, 0.85)      # Cool moonlight
const LIGHT_SHAFT_COLOR = Color(1.0, 0.95, 0.85, 0.3)

## Shadow settings
const SHADOW_LENGTH_DAY: float = 80.0          # Shadow offset at dawn/dusk
const SHADOW_LENGTH_NOON: float = 15.0         # Minimal shadow at noon
const SHADOW_LENGTH_NIGHT: float = 40.0        # Softer moonlight shadows

## How fast to lerp to target color (higher = faster)
const LERP_SPEED: float = 0.5

## Current time of day (0.0 to 1.0)
var time_of_day: float = 0.25  # Default to mid-day

## Reference to the CanvasModulate node
var canvas_modulate: CanvasModulate = null

## Reference to the sun/moon light
var sun_light: PointLight2D = null
var sun_glow: Sprite2D = null
var sun_particles: CPUParticles2D = null

## Target color we're lerping towards
var _target_color: Color = DAY_COLOR

## Day duration for local time advancement
var _day_duration: int = 2700  # 45 minutes default

## Last sync time for local advancement
var _last_sync_time: float = 0.0

## Has received first sync from server
var _has_synced: bool = false

## Cached textures/materials
var _light_texture: Texture2D
var _white_pixel_texture: Texture2D


func _ready() -> void:
	_last_sync_time = Time.get_ticks_msec() / 1000.0
	_light_texture = load("res://assets/light.png")
	_white_pixel_texture = _create_white_pixel_texture()
	print("[DayNightCycle] Ready - waiting for server time sync")


func _process(delta: float) -> void:
	# Only advance time locally after receiving first sync
	if _has_synced:
		_advance_local_time(delta)
	
	# Calculate target color based on current time
	_target_color = _calculate_color_for_time(time_of_day)
	
	# Smoothly lerp the CanvasModulate color
	if canvas_modulate:
		canvas_modulate.color = canvas_modulate.color.lerp(_target_color, LERP_SPEED * delta)
	
	# Update sun/moon light position and properties
	_update_sun_light(delta)


func _advance_local_time(delta: float) -> void:
	## Advance time locally to keep smooth progression between server syncs
	var time_increment = delta / float(_day_duration)
	time_of_day += time_increment
	
	# Wrap around at 1.0
	if time_of_day >= 1.0:
		time_of_day -= 1.0


func _on_time_update(data: Dictionary) -> void:
	## Called when server sends time update
	if data.is_empty():
		return
	
	time_of_day = data.get("time", time_of_day)
	_day_duration = data.get("day_duration", _day_duration)
	_last_sync_time = Time.get_ticks_msec() / 1000.0
	_has_synced = true
	
	print("[DayNightCycle] Time sync: %.3f (%s) - Day duration: %ds" % [time_of_day, data.get("phase", "Unknown"), _day_duration])


func _update_sun_light(_delta: float) -> void:
	## Update the sun/moon light based on time of day
	if not sun_light:
		return
	
	# Follow the local player so shadows are cast properly in view
	if InstanceClient.local_player and is_instance_valid(InstanceClient.local_player):
		var player_pos = InstanceClient.local_player.global_position
		
		# Calculate sun/moon position based on time
		# Sun/moon moves in an arc above the player
		var is_sun: bool = time_of_day < 0.5
		var arc_progress: float
		
		if is_sun:
			# Day: 0.0 (sunrise) -> 0.25 (noon) -> 0.5 (sunset)
			arc_progress = time_of_day / 0.5
		else:
			# Night: 0.5 (moonrise) -> 0.75 (midnight) -> 1.0 (moonset)
			arc_progress = (time_of_day - 0.5) / 0.5
		
		# Calculate horizontal offset: starts right (east), moves left (west)
		var horizontal_offset = lerp(400.0, -400.0, arc_progress)
		
		# Calculate vertical offset: low at horizon, high at noon/midnight
		# Use sine curve for natural arc
		var vertical_offset = -200.0 - sin(arc_progress * PI) * 300.0
		
		sun_light.global_position = player_pos + Vector2(horizontal_offset, vertical_offset)
		
		if sun_glow:
			sun_glow.global_position = sun_light.global_position
		
		if sun_particles:
			# Position particles above player so they drift down through the scene
			sun_particles.global_position = player_pos + Vector2(0, -150)
	
	# Calculate sun angle for shadow direction
	var is_sun: bool = time_of_day < 0.5
	var angle: float
	
	if is_sun:
		angle = lerp(-PI * 0.4, PI * 0.4, time_of_day / 0.5)
	else:
		angle = lerp(-PI * 0.4, PI * 0.4, (time_of_day - 0.5) / 0.5)
	
	# Shadow length varies: long at dawn/dusk, short at noon
	var shadow_length: float
	if is_sun:
		var noon_factor = 1.0 - abs(time_of_day - 0.25) * 4.0
		noon_factor = clampf(noon_factor, 0.0, 1.0)
		shadow_length = lerp(SHADOW_LENGTH_DAY, SHADOW_LENGTH_NOON, noon_factor)
	else:
		shadow_length = SHADOW_LENGTH_NIGHT
	
	# Update light color and energy based on time
	var target_light_color: Color
	var target_energy: float
	
	if time_of_day < 0.08:
		# Dawn - orange light rising
		var t = time_of_day / 0.08
		target_light_color = DAWN_LIGHT_COLOR
		target_energy = lerp(0.1, 0.8, t)
	elif time_of_day < 0.15:
		# Dawn to day transition
		var t = (time_of_day - 0.08) / 0.07
		target_light_color = DAWN_LIGHT_COLOR.lerp(SUN_COLOR, t)
		target_energy = lerp(0.8, 1.0, t)
	elif time_of_day < 0.40:
		# Full daylight
		target_light_color = SUN_COLOR
		target_energy = 1.0
	elif time_of_day < 0.47:
		# Day to dusk transition
		var t = (time_of_day - 0.40) / 0.07
		target_light_color = SUN_COLOR.lerp(DUSK_LIGHT_COLOR, t)
		target_energy = lerp(1.0, 0.8, t)
	elif time_of_day < 0.53:
		# Dusk - sun setting, moon not yet up
		var t = (time_of_day - 0.47) / 0.06
		target_light_color = DUSK_LIGHT_COLOR
		target_energy = lerp(0.8, 0.2, t)
	elif time_of_day < 0.58:
		# Moon rising
		var t = (time_of_day - 0.53) / 0.05
		target_light_color = MOON_COLOR
		target_energy = lerp(0.2, 0.5, t)
	elif time_of_day < 0.92:
		# Full moonlight
		target_light_color = MOON_COLOR
		target_energy = 0.5
	else:
		# Moon setting, approaching dawn
		var t = (time_of_day - 0.92) / 0.08
		target_light_color = MOON_COLOR.lerp(DAWN_LIGHT_COLOR, t * 0.5)
		target_energy = lerp(0.5, 0.1, t)
	
	# Apply light properties with smooth lerping
	sun_light.color = sun_light.color.lerp(target_light_color, LERP_SPEED * 0.3)
	sun_light.energy = lerp(sun_light.energy, target_energy, LERP_SPEED * 0.3)
	
	# Update glow scale/rotation for light shafts
	if sun_glow:
		var time = Time.get_ticks_msec() / 1000.0
		var pulse = 1.0 + sin(time * 0.5) * 0.1
		var base_scale = Vector2(8, 8) if is_sun else Vector2(5, 5)
		sun_glow.scale = base_scale * pulse
		sun_glow.rotation = time * 0.02
		
		# Sun: warm golden glow, Moon: cool silver glow
		var target_glow_color = Color(1.0, 0.95, 0.8, 0.25) if is_sun else Color(0.7, 0.8, 1.0, 0.15)
		sun_glow.modulate = sun_glow.modulate.lerp(target_glow_color, 0.02)
	
	# Update god rays
	_update_god_rays(is_sun)
	
	# Update floating light motes
	if sun_particles:
		sun_particles.emitting = is_sun  # Only emit during day
		if is_sun:
			# Brighter at dawn/dusk when sun is low
			var horizon_factor = 1.0 - abs(time_of_day - 0.25) * 2.0
			horizon_factor = clampf(horizon_factor, 0.3, 1.0)
			sun_particles.modulate = Color(1.0, 0.98, 0.9, horizon_factor * 0.5)


func _update_god_rays(is_sun: bool) -> void:
	if god_rays.is_empty():
		return
	
	var time = Time.get_ticks_msec() / 1000.0
	
	# Position rays at sun position
	var ray_pos = sun_glow.global_position if sun_glow else Vector2.ZERO
	
	var num_rays = god_rays.size()
	for i in range(num_rays):
		var ray = god_rays[i]
		ray.global_position = ray_pos
		ray.visible = is_sun  # Only show during day
		
		if not is_sun:
			continue
		
		# Animate each ray slightly differently
		var phase_offset = float(i) * 0.7
		var sway = sin(time * 0.2 + phase_offset) * 0.03
		
		# Fan pattern pointing downward from sun
		var angle_spread = PI * 0.6
		var base_angle = -PI/2 + (float(i) / float(num_rays - 1) - 0.5) * angle_spread
		ray.rotation = base_angle + sway
		
		# Pulse opacity - more visible
		var opacity_base = 0.12 + float(i % 3) * 0.04  # Vary base opacity
		var opacity_pulse = opacity_base + sin(time * 0.3 + phase_offset) * 0.05
		ray.modulate.a = lerp(ray.modulate.a, opacity_pulse, 0.03)
		
		# Scale pulse - height varies
		var base_height = 18.0 + float(i) * 3.0
		var scale_pulse = 1.0 + sin(time * 0.15 + phase_offset) * 0.15
		ray.scale.y = base_height * scale_pulse
		ray.scale.x = 1.2 + sin(time * 0.25 + phase_offset * 2.0) * 0.3


func _calculate_color_for_time(t: float) -> Color:
	## Calculate the appropriate color for the given time of day
	## Time phases:
	## 0.00 - 0.10: Dawn (Pre-dawn -> Dawn -> Day)
	## 0.10 - 0.40: Day (full daylight)
	## 0.40 - 0.50: Dusk (Day -> Dusk -> Evening)
	## 0.50 - 0.60: Evening (Evening -> Night)
	## 0.60 - 0.85: Night (deep night)
	## 0.85 - 1.00: Late Night (Night -> Pre-dawn)
	
	if t < 0.05:
		# Pre-dawn to Dawn
		var progress = t / 0.05
		return PRE_DAWN_COLOR.lerp(DAWN_COLOR, progress)
	elif t < 0.10:
		# Dawn to Day
		var progress = (t - 0.05) / 0.05
		return DAWN_COLOR.lerp(DAY_COLOR, progress)
	elif t < 0.40:
		# Full Day
		return DAY_COLOR
	elif t < 0.45:
		# Day to Dusk
		var progress = (t - 0.40) / 0.05
		return DAY_COLOR.lerp(DUSK_COLOR, progress)
	elif t < 0.50:
		# Dusk to Evening
		var progress = (t - 0.45) / 0.05
		return DUSK_COLOR.lerp(EVENING_COLOR, progress)
	elif t < 0.55:
		# Evening to Night
		var progress = (t - 0.50) / 0.05
		return EVENING_COLOR.lerp(NIGHT_COLOR, progress)
	elif t < 0.75:
		# Night to Midnight
		var progress = (t - 0.55) / 0.20
		return NIGHT_COLOR.lerp(MIDNIGHT_COLOR, progress)
	elif t < 0.90:
		# Midnight
		return MIDNIGHT_COLOR
	else:
		# Midnight to Pre-dawn
		var progress = (t - 0.90) / 0.10
		return MIDNIGHT_COLOR.lerp(PRE_DAWN_COLOR, progress)


## Set the CanvasModulate reference and create sun light
func set_canvas_modulate(modulate: CanvasModulate) -> void:
	canvas_modulate = modulate
	if canvas_modulate:
		# Initialize to current target
		_target_color = _calculate_color_for_time(time_of_day)
		canvas_modulate.color = _target_color
		print("[DayNightCycle] CanvasModulate connected")
		
		# Create the sun/moon light for dynamic shadows
		_create_sun_light()


func _create_sun_light() -> void:
	## Create a PointLight2D to simulate sun/moon with directional shadows
	if sun_light:
		return  # Already created
	
	sun_light = PointLight2D.new()
	sun_light.name = "SunMoonLight"
	
	if _light_texture:
		sun_light.texture = _light_texture
	
	# Configure as ambient directional light
	sun_light.texture_scale = 22.0  # Large coverage
	sun_light.energy = 0.85
	sun_light.color = SUN_COLOR
	sun_light.blend_mode = Light2D.BLEND_MODE_ADD
	
	# Shadows disabled
	sun_light.shadow_enabled = false
	
	# Position far above to simulate directional light
	sun_light.position = Vector2(0, -500)
	
	# Add to scene - parent to canvas_modulate's parent (the map)
	if canvas_modulate.get_parent():
		canvas_modulate.get_parent().add_child(sun_light)
		print("[DayNightCycle] Sun/Moon light created with shadows enabled")
		
		_create_sun_glow(canvas_modulate.get_parent())
		_create_sun_particles(canvas_modulate.get_parent())


func _create_sun_glow(parent_node: Node) -> void:
	if sun_glow:
		return
	
	# Main sun glow orb
	sun_glow = Sprite2D.new()
	sun_glow.name = "SunGlow"
	sun_glow.texture = _light_texture
	sun_glow.z_index = -50
	
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sun_glow.material = glow_material
	sun_glow.modulate = Color(1.0, 0.95, 0.8, 0.25)
	sun_glow.scale = Vector2(8, 8)
	
	parent_node.add_child(sun_glow)
	
	# Create god rays as child sprites
	_create_god_rays(parent_node)


var god_rays: Array[Sprite2D] = []

func _create_god_rays(parent_node: Node) -> void:
	# Create multiple ray sprites for god ray effect
	var num_rays = 8
	
	for i in range(num_rays):
		var ray = Sprite2D.new()
		ray.name = "GodRay_%d" % i
		ray.texture = _light_texture
		ray.z_index = -10  # In front of background but behind most objects
		
		var ray_material := CanvasItemMaterial.new()
		ray_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ray_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ray.material = ray_material
		
		# Each ray has different scale - tall and thin for shaft effect
		var ray_width = 1.5 + randf() * 1.0
		var ray_height = 20.0 + randf() * 15.0
		ray.scale = Vector2(ray_width, ray_height)
		
		# More visible opacity
		ray.modulate = Color(1.0, 0.95, 0.85, 0.15 + randf() * 0.1)
		
		# Spread rays in a fan pattern pointing downward
		var angle_spread = PI * 0.6  # 108 degree spread
		var base_angle = -PI/2 + (float(i) / float(num_rays - 1) - 0.5) * angle_spread
		ray.rotation = base_angle + (randf() - 0.5) * 0.1
		
		parent_node.add_child(ray)
		god_rays.append(ray)


func _create_sun_particles(parent_node: Node) -> void:
	if sun_particles:
		return
	
	sun_particles = CPUParticles2D.new()
	sun_particles.name = "SunDust"
	sun_particles.emitting = true
	sun_particles.amount = 12  # Sparse
	sun_particles.lifetime = 6.0
	sun_particles.one_shot = false
	sun_particles.speed_scale = 0.2
	sun_particles.direction = Vector2(0, 1)  # Drift downward like light filtering through
	sun_particles.spread = 30.0
	sun_particles.gravity = Vector2(0, 2)  # Gentle fall
	sun_particles.initial_velocity_min = 2.0
	sun_particles.initial_velocity_max = 5.0
	sun_particles.damping_min = 0.05
	sun_particles.damping_max = 0.15
	sun_particles.angular_velocity_min = -5.0
	sun_particles.angular_velocity_max = 5.0
	
	# Wide rectangular emission area (screen-wide)
	sun_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sun_particles.emission_rect_extents = Vector2(400, 250)  # Wide area
	
	# Small glowing particles
	sun_particles.texture = _light_texture
	sun_particles.scale_amount_min = 0.015
	sun_particles.scale_amount_max = 0.04
	
	# Fade in and out with scale curve
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.0))  # Start invisible
	scale_curve.add_point(Vector2(0.25, 1.0))  # Fade in
	scale_curve.add_point(Vector2(0.75, 1.0))  # Stay visible
	scale_curve.add_point(Vector2(1.0, 0.0))  # Fade out
	sun_particles.scale_amount_curve = scale_curve
	
	# Color fade: white-yellow glow that fades alpha
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(1.0, 1.0, 0.9, 0.0))  # Start transparent
	color_ramp.add_point(0.2, Color(1.0, 0.98, 0.85, 0.7))  # Fade in warm
	color_ramp.add_point(0.5, Color(1.0, 1.0, 0.95, 0.85))  # Peak brightness
	color_ramp.add_point(0.8, Color(1.0, 0.98, 0.85, 0.5))  # Start fade
	color_ramp.set_color(1, Color(1.0, 1.0, 0.9, 0.0))  # Fade out
	sun_particles.color_ramp = color_ramp
	
	# Additive blending for glow effect
	var particle_material = CanvasItemMaterial.new()
	particle_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sun_particles.material = particle_material
	
	sun_particles.z_index = 50
	
	parent_node.add_child(sun_particles)
	sun_particles.restart()


func _create_white_pixel_texture() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


## Check if it's currently day
func is_day() -> bool:
	return time_of_day < 0.5


## Check if it's currently night
func is_night() -> bool:
	return time_of_day >= 0.5


## Get current phase name
func get_phase_name() -> String:
	if time_of_day < 0.1:
		return "Dawn"
	elif time_of_day < 0.4:
		return "Day"
	elif time_of_day < 0.5:
		return "Dusk"
	elif time_of_day < 0.6:
		return "Evening"
	elif time_of_day < 0.9:
		return "Night"
	else:
		return "Late Night"
