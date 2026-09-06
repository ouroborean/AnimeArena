extends Character


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Veldora Tempest"
	path_name = "veldora"
	character_colors = [3]
	universe = CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME
	description = "Veldora Tempest, the True Storm Dragon and one of the Four True Dragons. Sealed away for centuries, his vast aura and storm-bending power return like an earthquake whenever the slumbering dragon is roused to act."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true


func _process(delta):
	pass
