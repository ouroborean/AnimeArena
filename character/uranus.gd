extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)


func initialize(_moveset = false):
	character_name = "Sailor Uranus"
	character_colors = [1, 2, 3]
	path_name = "uranus"
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Tenoh Haruka, the soldier of the sky. Sworn to defend the Outer Solar System alongside Neptune, Uranus carries the Space Sword and answers every threat with the resolve of a knight."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
