extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "BlackWarGreymon"
	path_name = "blackwargreymon"
	universe = CharacterConcept.Universe.DIGIMON
	character_colors = [3, 4]
	description = "An artificially-created Mega Digimon born from a hundred Control Spires, BlackWarGreymon is a being of overwhelming power searching for the meaning of its own existence. Cold and methodical, it cleaves through defenses with its Dramon Destroyers and tears its foes apart with the Black Tornado."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
