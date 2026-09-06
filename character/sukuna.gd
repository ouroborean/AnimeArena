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
	character_name = "Ryomen Sukuna"
	path_name = "sukuna"
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	description = "Ryomen Sukuna, the strongest Jujutsu sorcerer in history. Thought to originally be a demon, Sukuna actually split his soul between his 20 indestructible fingers to gain immortality. He bides his time until he has a chance to walk the earth once again."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
