extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1]
	character_name = "Hyuuga Hinata"
	path_name = "hinata"
	universe = CharacterConcept.Universe.NARUTO
	description = "Hinata Hyuuga, heir to the prestigious Hyuuga family. Though she is normally kind and gentle, she has a fiercely loyal and protective spirit that awakens in defense of her loved ones."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "hinata_unlock" in player.unlocks

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
