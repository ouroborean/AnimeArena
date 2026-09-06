extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Piccolo"
	path_name = "piccolo"
	character_colors = [0]
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Piccolo, the Namekian warrior born of the Demon King Piccolo. Once Goku's fiercest rival, he became Earth's guardian and Gohan's mentor — a patient tactician who fuses with Nail and Kami to grow ever stronger, regenerating from near death and charging techniques that split the sky."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "piccolo_unlock" in player.unlocks

func _process(delta):
	pass
