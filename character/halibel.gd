extends Character


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Tia Halibel"
	path_name = "halibel"
	character_colors = [1]
	universe = CharacterConcept.Universe.BLEACH
	description = "Tia Halibel, the Tres Espada and Aspect of Sacrifice. Stoic and dutiful, she shields her allies by drawing damage onto herself, then unleashes the building tide as her Resurrección, Tiburón, is forced into release."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true


func _process(delta):
	pass
