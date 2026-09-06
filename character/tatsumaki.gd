extends Character
class_name Tatsumaki


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Tatsumaki"
	path_name = "tatsumaki"
	universe = CharacterConcept.Universe.ONE_PUNCH_MAN
	description = "Tatsumaki, the Tornado of Terror, is the Hero Associations Rank 2 hero, and the most powerful esper in the world. She prefers to work alone, using her unparalleled psychic powers and caustic personality to ward off both threats and allies."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
