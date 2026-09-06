extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Crona"
	path_name = "crona"
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Crona, a sad child who was raised by the witch Medusa. His mother's torment made him a prime vessel for the Black Blade Ragnarok, whose twisted power makes Crona a fearsome opponent while steadily driving him insane."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "crona_unlock" in player.unlocks

func _process(delta):
	pass
