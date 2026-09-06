extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1]
	character_name = "Tsubasa Kazanari"
	path_name = "tsubasa"
	universe = CharacterConcept.Universe.SYMPHOGEAR
	description = "Tsubasa Kazanari, wielder of the Blue Symphogear Ame no Habakiri. Heir to the Kazanari sword arts, she fights with the disciplined grace of a swordmaster and a fierce, self-sacrificing devotion to protecting those she calls comrades."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "tsubasa_unlock" in player.unlocks

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
