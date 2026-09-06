extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Astolfo"
	path_name = "astolfo"
	universe = CharacterConcept.Universe.FATE
	character_colors = [0, 3]
	description = "The Rider of Black. A cheerful, fearless knight of Charlemagne who rides the Hippogriff into battle, Astolfo wields a trove of Noble Phantasms - the maddening lance Trap of Argalia, the anti-magic tome Casseur de Logistille, and La Black Luna to sweep the field."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
