extends Character


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Nelliel tu Odelschwank"
	path_name = "nel"
	character_colors = [0, 2]
	universe = CharacterConcept.Universe.BLEACH
	description = "Nelliel tu Odelschwank, the former Tres Espada. With her zanpakuto Gamuza unleashed, Nel shields her allies from harm and punishes enemies who would dare take advantage of their weaknesses."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true


func _process(delta):
	pass
