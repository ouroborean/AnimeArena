extends Character
class_name Usopp


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = []
	character_name = "Usopp"
	path_name = "usopp"
	universe = CharacterConcept.Universe.ONE_PIECE
	description = "C'mon, you know him, he's Usopp. Slingshot guy, yeah."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
