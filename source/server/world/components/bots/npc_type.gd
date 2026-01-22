class_name NPCType
## Enum defining the different types of NPCs in Kraftovia.
##
## VILLAGER_WORKER: Hireable workers (Rocky, Fern, Jack) - wander near station, leave when hired
## VILLAGER_SERVICE: Service NPCs like blacksmiths, merchants (4th class) - future
## VILLAGER_AMBIENT: Decorative wanderers for atmosphere - no interaction
## PLAYER_INACTIVE: Player's other characters when not actively controlled

enum Type {
	VILLAGER_WORKER,   ## Hireable workers (miner, forager, trapper)
	VILLAGER_SERVICE,  ## Service NPCs (blacksmith, merchant) - future
	VILLAGER_AMBIENT,  ## Decorative wanderers
	PLAYER_INACTIVE,   ## Player's inactive characters
}
