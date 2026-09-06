extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Ai Ohto"
	path_name = "aiohto"
	universe = CharacterConcept.Universe.WONDER_EGG_PRIORITY
	character_colors = [0, 3]
	description = "A withdrawn 14-year-old with heterochromatic eyes, isolated after the suicide of her only friend, Koito. To bring her back, Ai descends into a dream world each night and arms herself with gachapon weapons to battle the Wonder Killers that torment other grieving girls - fragile and full of doubt, but refusing to give up."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
