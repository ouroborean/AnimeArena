extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Jesse Anderson"
	path_name = "jesse"
	character_colors = [0]
	universe = CharacterConcept.Universe.YUGIOH
	description = "Jesse Anderson, a duelist from North Academy who enters the Duel Academy. Jesse is kind and excitable, and his Crystal Beast monsters linger on the field to continue lending their strength to the battle."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
