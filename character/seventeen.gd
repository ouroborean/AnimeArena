extends Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1, 2, 3]
	character_name = "Android 17"
	universe = CharacterConcept.Universe.DRAGON_BALL
	path_name = "seventeen"
	description = "Once Dr. Gero's reluctant creation, Android 17 is a cyborg with a limitless internal energy reactor. Cool-headed and free-spirited, he fights at his own pace — cycling infinite energy into overwhelming barrages, barriers, and blasts."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
