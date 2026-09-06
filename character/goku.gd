extends Character
class_name Goku


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
 
func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Son Goku"
	path_name = "goku"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Son Goku, a Saiyan raised on Earth. A lifelong martial artist with a pure heart, Goku shook free of the shackles of his warrior race and became Earth's greatest champion."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
