extends Character
class_name Frankenstein


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Frankenstein"
	path_name = "frankenstein"
	universe = CharacterConcept.Universe.FATE
	description = "Created through science, Frankenstein was summoned to serve as a Berserker servant of the Black Faction in the Great Holy Grail War. Her attacks carry devastating weight and she can channel lightning to destructive effect."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "frankenstein_unlock" in player.unlocks

func _process(delta):
	pass
