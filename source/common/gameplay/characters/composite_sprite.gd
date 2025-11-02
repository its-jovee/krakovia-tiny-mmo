class_name CompositeSprite
extends Node2D
## Manages layered sprite rendering for character customization
## Handles Base (animated), Hair (animated, disabled), Head (animated frame-synced), Accessory (static, disabled)

signal appearance_changed()

# Layer nodes
var base_sprite: AnimatedSprite2D
var hair_sprite: AnimatedSprite2D
var head_sprite: AnimatedSprite2D  # Head layer - animated frame-by-frame with body
var accessory_sprite: Node2D  # Can be Sprite2D or AnimatedSprite2D depending on equipment

# Current appearance
var character_class: String = "miner"
var head_id: String = "0"
var hair_id: String = "none"  # Disabled
var accessory_id: String = "none"  # Disabled

# Animation state
var current_animation: String = "idle"
var is_flipped: bool = false

# Shader references
var animation_shader: ShaderMaterial = null
var animation_time_offset: float = 0.0


func _ready() -> void:
	_setup_sprite_layers()
	_setup_animation_shader()
	
	# Connect frame sync for composite layers
	if base_sprite:
		base_sprite.frame_changed.connect(_sync_layers_to_base)


func _setup_sprite_layers() -> void:
	"""Create the 4 sprite layer nodes"""
	# Base layer (animated body)
	base_sprite = AnimatedSprite2D.new()
	base_sprite.name = "BaseSprite"
	base_sprite.sprite_frames = null
	base_sprite.offset = Vector2(0, 0)  # No offset - handled by parent position
	base_sprite.scale = Vector2(0.8, 0.8)
	add_child(base_sprite)
	
	# Hair layer (animated, on top of base) - Initially disabled
	hair_sprite = AnimatedSprite2D.new()
	hair_sprite.name = "HairSprite"
	hair_sprite.sprite_frames = null
	hair_sprite.offset = Vector2(0, 0)  # No offset - handled by parent position
	hair_sprite.scale = Vector2(0.8, 0.8)
	hair_sprite.visible = false  # Disabled initially
	add_child(hair_sprite)
	
	# Head layer (animated to match body movement frame-by-frame)
	head_sprite = AnimatedSprite2D.new()
	head_sprite.name = "HeadSprite"
	head_sprite.sprite_frames = null
	head_sprite.offset = Vector2(0, 0)  # No offset - handled by parent position
	head_sprite.scale = Vector2(0.8, 0.8)
	add_child(head_sprite)
	
	# Accessory layer (animated like head) - Initially disabled
	accessory_sprite = AnimatedSprite2D.new()
	accessory_sprite.name = "AccessorySprite"
	accessory_sprite.sprite_frames = null
	accessory_sprite.offset = Vector2(0, 0)  # No offset - handled by parent position
	accessory_sprite.scale = Vector2(0.8, 0.8)
	accessory_sprite.visible = false  # Disabled initially
	add_child(accessory_sprite)


func _setup_animation_shader() -> void:
	"""Setup procedural shader animations for all layers"""
	if multiplayer.is_server():
		return
	
	var shader = load("res://source/client/shaders/character_animation.gdshader")
	if not shader:
		return
	
	animation_shader = ShaderMaterial.new()
	animation_shader.shader = shader
	
	# Randomize time offset so characters don't breathe in sync
	animation_time_offset = randf() * TAU
	animation_shader.set_shader_parameter("time_offset", animation_time_offset)
	
	# Set default parameters
	animation_shader.set_shader_parameter("breathing_intensity", 0.6)
	animation_shader.set_shader_parameter("breathing_speed", 2.5)
	animation_shader.set_shader_parameter("squash_stretch_intensity", 0.08)
	animation_shader.set_shader_parameter("squash_stretch_speed", 4.0)
	animation_shader.set_shader_parameter("animation_state", 0)
	
	# Apply to all layers (each needs its own duplicate to prevent shared state)
	base_sprite.material = animation_shader
	
	# Apply to head layer
	if head_sprite:
		head_sprite.material = animation_shader.duplicate()
	
	# Apply to hair layer (when visible)
	if hair_sprite:
		hair_sprite.material = animation_shader.duplicate()
	
	# Apply to accessory layer (when visible)
	if accessory_sprite:
		var accessory_shader = animation_shader.duplicate()
		accessory_sprite.material = accessory_shader


func set_appearance(char_class: String, head: String, hair: String = "none", accessory: String = "none") -> void:
	"""Set the complete appearance of the character"""
	character_class = char_class
	head_id = head
	hair_id = hair
	accessory_id = accessory
	
	_load_base_sprite()
	_load_head_sprite()
	# Hair and accessory disabled initially
	
	appearance_changed.emit()


func equip_accessory(equipment: EquipmentResource) -> void:
	"""Equip an accessory item (uses EquipmentResource for cross-class support)"""
	if not equipment:
		unequip_accessory()
		return
	
	# Get class-specific sprite frames
	var frames: SpriteFrames = equipment.get_sprite_frames_for_class(character_class)
	if not frames:
		push_error("CompositeSprite: Could not load sprite frames for equipment '%s'" % equipment.item_id)
		return
	
	# Accessory is always AnimatedSprite2D (same as head)
	accessory_sprite.sprite_frames = frames
	accessory_sprite.visible = true
	accessory_sprite.play(current_animation)
	
	# Apply shader if on client
	if animation_shader and accessory_sprite.material == null:
		accessory_sprite.material = animation_shader.duplicate()
	
	print("[CompositeSprite] Equipped accessory with frames for class '%s'" % character_class)


func unequip_accessory() -> void:
	"""Remove currently equipped accessory"""
	print("[CompositeSprite] unequip_accessory() called!")
	if accessory_sprite:
		print("  → Setting accessory_sprite.visible = false")
		accessory_sprite.visible = false
		accessory_sprite.sprite_frames = null
		print("  → ✅ Accessory unequipped! Visible: %s" % accessory_sprite.visible)
	else:
		print("  → ✗ No accessory_sprite found!")


func _load_base_sprite() -> void:
	"""Load the base body sprite from composite folder structure"""
	if character_class.is_empty():
		push_error("CompositeSprite: Cannot load base sprite - character_class is empty!")
		return
	
	# Use new organized structure: composite/{class}/base/{class}.tres
	var sprite_frames_path: String = CompositePartRegistry.get_animated_spriteframes_path(
		character_class,
		CompositePartRegistry.Layer.BASE,
		"default"
	)
	
	if ResourceLoader.exists(sprite_frames_path):
		base_sprite.sprite_frames = load(sprite_frames_path)
		if base_sprite.sprite_frames and base_sprite.sprite_frames.has_animation(current_animation):
			base_sprite.play(current_animation)
		else:
			push_warning("CompositeSprite: Base sprite has no animation '%s'" % current_animation)
	else:
		push_error("CompositeSprite: Base sprite frames not found: %s" % sprite_frames_path)


func _load_head_sprite() -> void:
	"""Load the animated head sprite frames"""
	if head_id == "none" or head_id.is_empty():
		head_sprite.sprite_frames = null
		head_sprite.visible = false
		return
	
	if character_class.is_empty():
		push_error("CompositeSprite: Cannot load head sprite - character_class is empty!")
		return
	
	# Load head SpriteFrames from organized structure: composite/{class}/head/{id}.tres
	var head_frames_path: String = CompositePartRegistry.get_animated_spriteframes_path(
		character_class,
		CompositePartRegistry.Layer.HEAD,
		head_id
	)
	
	if ResourceLoader.exists(head_frames_path):
		head_sprite.sprite_frames = load(head_frames_path)
		head_sprite.visible = true
		if head_sprite.sprite_frames and head_sprite.sprite_frames.has_animation(current_animation):
			head_sprite.play(current_animation)
		else:
			push_warning("CompositeSprite: Head sprite '%s' has no animation '%s'" % [head_id, current_animation])
	else:
		push_warning("CompositeSprite: Head sprite frames not found: %s (head will not display)" % head_frames_path)
		head_sprite.sprite_frames = null
		head_sprite.visible = false


func play_animation(anim_name: String) -> void:
	"""Play animation on animated layers (synced frame-by-frame)"""
	current_animation = anim_name
	
	if base_sprite and base_sprite.sprite_frames:
		base_sprite.play(anim_name)
		
		# Sync head animation (frame-by-frame with body)
		if head_sprite and head_sprite.visible and head_sprite.sprite_frames:
			head_sprite.play(anim_name)
			head_sprite.set_frame_and_progress(base_sprite.frame, base_sprite.get_frame_progress())
		
		# Sync hair when enabled
		if hair_sprite and hair_sprite.visible and hair_sprite.sprite_frames:
			hair_sprite.play(anim_name)
			hair_sprite.set_frame_and_progress(base_sprite.frame, base_sprite.get_frame_progress())
		
		# Sync animated accessory when enabled
		if accessory_sprite and accessory_sprite.visible and accessory_sprite is AnimatedSprite2D:
			var animated_accessory := accessory_sprite as AnimatedSprite2D
			if animated_accessory.sprite_frames:
				animated_accessory.play(anim_name)
				animated_accessory.set_frame_and_progress(base_sprite.frame, base_sprite.get_frame_progress())
	
	# Update shader animation state
	_update_animation_shader_state(anim_name)


func _sync_layers_to_base() -> void:
	"""Keep head, hair, and animated accessories frame-synced with base body animation"""
	if not base_sprite or not base_sprite.is_playing():
		return
	
	var current_frame := base_sprite.frame
	var frame_progress := base_sprite.get_frame_progress()
	
	# Sync head layer
	if head_sprite and head_sprite.visible and head_sprite.sprite_frames:
		if head_sprite.animation == base_sprite.animation:
			head_sprite.set_frame_and_progress(current_frame, frame_progress)
	
	# Sync hair layer
	if hair_sprite and hair_sprite.visible and hair_sprite.sprite_frames:
		if hair_sprite.animation == base_sprite.animation:
			hair_sprite.set_frame_and_progress(current_frame, frame_progress)
	
	# Sync animated accessory layer
	if accessory_sprite and accessory_sprite.visible and accessory_sprite is AnimatedSprite2D:
		var animated_accessory := accessory_sprite as AnimatedSprite2D
		if animated_accessory.sprite_frames and animated_accessory.animation == base_sprite.animation:
			animated_accessory.set_frame_and_progress(current_frame, frame_progress)


func set_flipped(flipped: bool) -> void:
	"""Flip all layers horizontally (all layers sync)"""
	is_flipped = flipped
	
	if base_sprite:
		base_sprite.flip_h = flipped
	if head_sprite:
		head_sprite.flip_h = flipped
	if hair_sprite:
		hair_sprite.flip_h = flipped
	if accessory_sprite:
		accessory_sprite.flip_h = flipped


func _update_animation_shader_state(anim_name: String) -> void:
	"""Update shader parameters based on current animation for all layers"""
	if not animation_shader:
		return
	
	var state_enum: int = 0
	var breathing_speed: float = 2.5
	var squash_speed: float = 4.0
	
	match anim_name:
		"idle":
			state_enum = 0
			breathing_speed = 2.5
		"sit":
			state_enum = 2
			breathing_speed = 1.8
		"run", "harvest":
			state_enum = 1
			squash_speed = 5.0
	
	# Update all layer shaders
	var shaders_to_update: Array[ShaderMaterial] = []
	if base_sprite and base_sprite.material is ShaderMaterial:
		shaders_to_update.append(base_sprite.material)
	if head_sprite and head_sprite.material is ShaderMaterial:
		shaders_to_update.append(head_sprite.material)
	if hair_sprite and hair_sprite.visible and hair_sprite.material is ShaderMaterial:
		shaders_to_update.append(hair_sprite.material)
	if accessory_sprite and accessory_sprite.visible and accessory_sprite.material is ShaderMaterial:
		shaders_to_update.append(accessory_sprite.material)
	
	for shader_mat in shaders_to_update:
		shader_mat.set_shader_parameter("animation_state", state_enum)
		shader_mat.set_shader_parameter("breathing_speed", breathing_speed)
		shader_mat.set_shader_parameter("squash_stretch_speed", squash_speed)


func get_base_sprite() -> AnimatedSprite2D:
	"""Get reference to base sprite for external access"""
	return base_sprite


func apply_shader_to_all_layers(shader_material: ShaderMaterial) -> void:
	"""Apply a shader material to all sprite layers"""
	if base_sprite:
		base_sprite.material = shader_material
	if hair_sprite and hair_sprite.visible:
		hair_sprite.material = shader_material.duplicate()
	if head_sprite:
		head_sprite.material = shader_material.duplicate()
	if accessory_sprite and accessory_sprite.visible:
		accessory_sprite.material = shader_material.duplicate()
	
	animation_shader = shader_material
