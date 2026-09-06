extends Character
class_name Gatomon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 2]
	character_name = "Gatomon"
	path_name = "gatomon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "A Holy Beast Digimon. With a small body and a curious, prank-loving nature, its appearance does not match the true strength it possesses. "
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "gatomon_unlock" in player.unlocks

func _process(delta):
	pass
