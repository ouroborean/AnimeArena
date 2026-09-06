extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [3]
	character_name = "Inuyasha"
	path_name = "inuyasha"
	universe = CharacterConcept.Universe.INUYASHA
	description = "Inuyasha, the half-demon spawn of a powerful yokai and a human woman. Though powerful in his own right, his half-breed blood causes him to intermittently lose his abilities by becoming fully human, or become an unstoppable monster when his demonic blood takes over."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "inuyasha_unlock" in player.unlocks

func _process(delta):
	pass
