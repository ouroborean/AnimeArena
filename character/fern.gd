extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func initialize(_moveset = false):
	character_name = "Fern"
	path_name = "fern"
	universe = CharacterConcept.Universe.FRIEREN
	character_colors = [1, 2]
	description = "Fern, Frieren's apprentice and the most gifted mage of her generation. Raised to treat magic as discipline rather than wonder, she fights with immaculate efficiency - suppressing her mana until the moment it matters, then spending every drop of it at once."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
