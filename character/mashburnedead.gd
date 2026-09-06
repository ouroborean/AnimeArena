extends Character
class_name MashBurnedead


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)


func initialize(_moveset = false):
	character_colors = [0]
	character_name = "Mash Burnedead"
	path_name = "mashburnedead"
	universe = CharacterConcept.Universe.MASHLE
	description = "Mash Burnedead is a boy born without a shred of magic in a world that lives and dies by it — so he trained his body to the absurd instead, cracking spells in half with raw muscle. Stoic and endlessly hungry for cream puffs, he punches through magic that should be impossible to beat by hand."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return "mashburnedead_unlock" in player.unlocks


func _process(delta):
	pass
