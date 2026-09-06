extends Character
class_name Mars


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Sailor Mars"
	path_name = "mars"
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Rei Hino is a Shinto Priestess better known as her alter ego, Sailor Mars. Together with the rest of the Sailor Guardians, they protect the Solar System from evil."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "mars_unlock" in player.unlocks

func _process(delta):
	pass
