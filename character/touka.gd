extends Character
class_name Touka


# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Touka Kirishima"
	path_name = "touka"
	universe = CharacterConcept.Universe.TOKYO_GHOUL
	description = "Touka Kirishima is a fiercely independent and determined character in the world of Tokyo Ghoul. She is a ghoul, a creature that must consume human flesh to survive, and is a member of the ghoul group known as Anteiku."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func _process(delta):
	pass
