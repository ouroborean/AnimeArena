extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Muzan Kibutsuji"
	path_name = "muzan"
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "Muzan Kibutsuji, the first and progenitor demon — the King of Demons. Obsessed with conquering the sun and reaching perfect immortality, he rules the Twelve Kizuki through fear. His Blood Demon Art rewrites flesh at a touch: he bleeds his enemies dry, experiments on his own to fuel his power, and seals his every wound in an instant."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "muzan_unlock" in player.unlocks

func _process(delta):
	pass
