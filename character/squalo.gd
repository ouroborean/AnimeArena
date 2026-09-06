extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Superbia Squalo"
	path_name = "squalo"
	character_colors = [0, 2]
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	description = "Superbia Squalo, second-in-command of the Varia. A savage and proud swordsman, Squalo has travelled the world defeating swordmasters, all for the sake of crowning himself Sword Emperor."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
