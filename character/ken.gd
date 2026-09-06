extends Character
class_name Ken


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [2]
	character_name = "Ken Kaneki"
	path_name = "ken"
	universe = CharacterConcept.Universe.TOKYO_GHOUL
	description = "A human who's life changed forever after having a Ghoul's organ transplanted into his body. Kaneki is effectively both human and ghoul, and lives in two worlds where he doesn't feel like he belongs."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
