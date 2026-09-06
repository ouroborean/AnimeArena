extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Gogeta"
	path_name = "gogeta"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Gogeta, the fusion between Goku and Vegeta. When the two strongest Saiyans combine, the result is a warrior so overwhelmingly powerful that even the mightiest beings in the universe become weaklings to toy with."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
