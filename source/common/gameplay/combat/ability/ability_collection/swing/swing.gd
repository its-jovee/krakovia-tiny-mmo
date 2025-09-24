extends AbilityResource


var damage: float = 10.0


func _init() -> void:
	cooldown = 1.5
	costs = { "hp": 5.0 }


func use_ability(entity: Entity, direction: Vector2) -> void:
	entity
	# cooldown is marked by Weapon.try_perform_action after successful execution
