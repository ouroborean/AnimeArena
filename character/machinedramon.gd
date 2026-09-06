extends Character
class_name Machinedramon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1, 2, 3]
	character_name = "Machinedramon"
	path_name = "machinedramon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "Machinedramon is a Machine Digimon, built by synthesizing the parts of many Cyborg Digimon."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "machinedramon_unlock" in player.unlocks

func _process(delta):
	pass
