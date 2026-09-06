extends Character
class_name Rimuru


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 2, 3]
	character_name = "Rimuru Tempest"
	path_name = "rimuru"
	universe = CharacterConcept.Universe.THAT_TIME_I_GOT_REINCARNATED_AS_A_SLIME
	description = "Rimuru is the founder and King of the monster country Tempest of the Jura Forest. He is regarded as one of the strongest among the Eight Star Demon Lords."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
