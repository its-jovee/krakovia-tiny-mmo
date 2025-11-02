@icon("res://assets/node_icons/blue/icon_character.png")
class_name Character
extends Entity


enum Animations {
	IDLE,
	RUN,
	HARVEST,
	SIT
}

#var hand_type: Hand.Types
#
#var weapon_name_right: String:
	#set = _set_right_weapon
#var weapon_name_left: String:
	#set = _set_left_weapon
#var equipped_weapon_right: Weapon
#var equipped_weapon_left: Weapon

var character_class: String:
	set = _set_character_class
var character_resource: CharacterResource

var sprite_frames: String = "miner":
	set = _set_sprite_frames

var anim: Animations = Animations.IDLE:
	set = _set_anim

var flipped: bool = false:
	set = _set_flip

var pivot: float = 0.0:
	set = _set_pivot

# Appearance customization
var appearance_head_id: String = "head_a":
	set = _set_appearance_head

var equipped_accessory_id: int = -1:
	set = _set_equipped_accessory

# Shader animation system
var animation_shader: ShaderMaterial = null
var animation_time_offset: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var composite_sprite: Node2D = get_node_or_null("CompositeSprite")
#@onready var hand_offset: Node2D = $HandOffset
#@onready var hand_pivot: Node2D = $HandOffset/HandPivot

#@onready var right_hand_spot: Node2D = $HandOffset/HandPivot/RightHandSpot
#@onready var left_hand_spot: Node2D = $HandOffset/HandPivot/LeftHandSpot

@onready var state_synchronizer: StateSynchronizer = $StateSynchronizer
@onready var ability_system_component: AbilitySystemComponent = $AbilitySystemComponent
@onready var equipment_component: EquipmentComponent = $EquipmentComponent
#@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var animation_tree: AnimationTree = $AnimationTree


func _ready() -> void:
	# Initialize character visuals
	if composite_sprite:
		# Ensure character_class is set before initializing sprites
		if character_class.is_empty():
			character_class = "miner"  # Fallback default
		
		# Use new composite sprite system
		composite_sprite.set_appearance(character_class, appearance_head_id)
		composite_sprite.play_animation("idle")
		
		# Hide legacy sprite when using composite system
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.visible = false
	else:
		# Fallback to legacy single sprite
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.visible = true
		
		sprite_frames = "miner"  # Default, will be overridden by character_class if set
		anim = Animations.IDLE
		# Setup shader-based procedural animations
		_setup_animation_shader()
	
	## NEW
	#$AbilitySystemComponent/AttributesMirror.attribute_local_changed.connect(
		#func(attr: StringName, value: float, max_value: float):
			##print(attr, " value = ", value, " max_value = ", max_value)
			#if attr != &"health":
				#return
			#$ProgressBar.value = value
			#$ProgressBar.max_value = max_value
	#)
	
	# OLD
	#if right_hand_spot.get_child_count():
		#equipped_weapon_right = right_hand_spot.get_child(0)
		#equipped_weapon_right.hand.type = hand_type
		#equipped_weapon_right.hand.side = Hand.Sides.RIGHT
		#equipped_weapon_right.character = self
	#if left_hand_spot.get_child_count():
		#equipped_weapon_left = left_hand_spot.get_child(0)
		#equipped_weapon_left.hand.type = hand_type
		#equipped_weapon_left.hand.side = Hand.Sides.LEFT
		#equipped_weapon_left.character = self


#func change_weapon(weapon_path: String, _side: bool = true) -> void:
	#if equipped_weapon_right:
		#equipped_weapon_right.queue_free()
	#var new_weapon: Weapon = load("res://source/common/gameplay/items/weapons/" + 
		#weapon_path + ".tscn").instantiate()
	#new_weapon.character = self
	##right_hand_spot.add_child(new_weapon)
	#equipped_weapon_right = new_weapon


#func update_weapon_animation(state: String) -> void:
	#pass
	##$AnimationTree.set("parameters/OnFoot/Blend2/blend_amount", 1.0)
	##equipped_weapon_right.play_animation(state)
	##equipped_weapon_left.play_animation(state)


#func _set_left_weapon(weapon_name: String) -> void:
	#weapon_name_left = weapon_name
	#change_weapon(weapon_name, false)


#func _set_right_weapon(weapon_name: String) -> void:
	#weapon_name_right = weapon_name
	#change_weapon(weapon_name, true)


func _set_sprite_frames(new_sprite_frames: String) -> void:
	animated_sprite.sprite_frames = ResourceLoader.load(
		"res://source/common/gameplay/characters/sprite_frames/" + new_sprite_frames + ".tres"
	)

func _set_anim(new_anim: Animations) -> void:
	anim = new_anim
	
	var anim_name: String = ""
	match new_anim:
		Animations.IDLE:
			anim_name = "idle"
		Animations.RUN:
			anim_name = "run"
		Animations.HARVEST:
			anim_name = "harvest"
		Animations.SIT:
			anim_name = "sit"
	
	# Use composite sprite if available, otherwise fall back to legacy
	if composite_sprite:
		composite_sprite.play_animation(anim_name)
	else:
		animated_sprite.play(anim_name)
		# Update shader animation state
		_update_animation_shader_state(new_anim)


func _set_flip(new_flip: bool) -> void:
	flipped = new_flip
	
	if composite_sprite:
		composite_sprite.set_flipped(new_flip)
	else:
		animated_sprite.flip_h = new_flip
	#hand_offset.scale.x = -1 if new_flip else 1


func _set_pivot(new_pivot: float) -> void:
	pivot = new_pivot
	#hand_pivot.rotation = new_pivot


func _set_character_class(new_class: String):
	character_class = new_class
	character_resource = ResourceLoader.load(
		"res://source/common/gameplay/characters/classes/character_collection/" + new_class + ".tres")
	
	if composite_sprite:
		composite_sprite.set_appearance(new_class, appearance_head_id)
	else:
		animated_sprite.sprite_frames = character_resource.character_sprite


func _set_appearance_head(new_head_id: String) -> void:
	appearance_head_id = new_head_id
	
	if composite_sprite and is_node_ready():
		composite_sprite.set_appearance(character_class, new_head_id)


func _set_equipped_accessory(new_id: int) -> void:
	"""Update equipped accessory when synced from server"""
	print("[Character] _set_equipped_accessory called! Old: %d, New: %d" % [equipped_accessory_id, new_id])
	equipped_accessory_id = new_id
	
	if not composite_sprite:
		print("[Character] No composite_sprite found!")
		return
	
	if new_id == -1:
		# Unequip
		print("[Character] Calling unequip_accessory()...")
		composite_sprite.unequip_accessory()
		print("[Character] ✅ Unequipped accessory")
	else:
		# Equip
		var item: Item = ContentRegistryHub.load_by_id(&"items", new_id)
		if item and item is EquipmentItem:
			var equipment_item := item as EquipmentItem
			if equipment_item.equipment:
				composite_sprite.equip_accessory(equipment_item.equipment)
				print("[Character] ✅ Equipped accessory: %s" % item.item_name)
			else:
				push_error("[Character] EquipmentItem has no equipment resource: %s" % item.item_name)
		else:
			push_error("[Character] Could not load equipment item ID %d" % new_id)


func _setup_animation_shader() -> void:
	"""Setup procedural shader animations for breathing and squash/stretch"""
	if not multiplayer.is_server():  # Only setup on client
		var shader = load("res://source/client/shaders/character_animation.gdshader")
		if shader and animated_sprite:
			animation_shader = ShaderMaterial.new()
			animation_shader.shader = shader
			
			# Randomize time offset so characters don't breathe in sync
			animation_time_offset = randf() * TAU
			animation_shader.set_shader_parameter("time_offset", animation_time_offset)
			
			# Set default parameters - expressive breathing, subtle squash/stretch
			animation_shader.set_shader_parameter("breathing_intensity", 0.6)
			animation_shader.set_shader_parameter("breathing_speed", 2.5)
			animation_shader.set_shader_parameter("squash_stretch_intensity", 0.08)
			animation_shader.set_shader_parameter("squash_stretch_speed", 4.0)
			animation_shader.set_shader_parameter("animation_state", 0)  # Start with idle
			
			# Apply shader to sprite
			animated_sprite.material = animation_shader


func _update_animation_shader_state(new_anim: Animations) -> void:
	"""Update shader parameters based on current animation"""
	if not animation_shader:
		return
	
	match new_anim:
		Animations.IDLE:
			animation_shader.set_shader_parameter("animation_state", 0)
			animation_shader.set_shader_parameter("breathing_speed", 2.5)  # Normal breathing
		
		Animations.SIT:
			animation_shader.set_shader_parameter("animation_state", 2)
			animation_shader.set_shader_parameter("breathing_speed", 1.8)  # Slightly slower when sitting
		
		Animations.RUN, Animations.HARVEST:
			animation_shader.set_shader_parameter("animation_state", 1)
			animation_shader.set_shader_parameter("squash_stretch_speed", 5.0)  # Match movement pace


#var primary_weapon: Weapon
#var secondary_weapon: Weapon
#func equip_weapon(weapon_id: int) -> void:
	##var weapon: Weapon = ContentRegistryHub.load_by_id(&"weapons", weapon_id)
	##if not weapon:
		##return
	#pass
	#
#func handle_action(index: int, direction: Vector2) -> void:
	#
	#pass

#func equip_weapon(mount_point: StringName, scene: PackedScene) -> void:
	#if mount_point == &"weapon_main":
		#var weapon: Weapon = scene.instantiate()
		#weapon.character = self
		#if equipped_weapon_right:
			#equipped_weapon_right.queue_free()
		##right_hand_spot.add_child(weapon)
		#equipped_weapon_right = weapon

#
#func unequip_weapon(mount_point: StringName) -> void:
	#if mount_point == &"weapon_main":
		#if equipped_weapon_right:
			#equipped_weapon_right.queue_free()
