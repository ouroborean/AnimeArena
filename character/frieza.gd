extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func initialize(_moveset = false):
	character_name = "Frieza"
	path_name = "frieza"
	universe = CharacterConcept.Universe.DRAGON_BALL
	character_colors = [3]
	description = "Frieza, the emperor of Universe 7. He rules through casual, unhurried cruelty - picking his prey apart with pinpoint death beams, shrugging off retaliation behind a wall of energy, and leaving a planet-killing sphere hanging overhead as a promise rather than a threat."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
