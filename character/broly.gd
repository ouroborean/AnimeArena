extends Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Broly"
	universe = CharacterConcept.Universe.DRAGON_BALL
	path_name = "broly"
	description = "The Legendary Super Saiyan. Broly is a living engine of escalating destruction — every blow he takes only stokes his rage, swelling his power without limit until the battlefield itself is shattered beneath planet-cracking energy."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
