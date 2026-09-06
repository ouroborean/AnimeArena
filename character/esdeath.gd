extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Esdeath"
	path_name = "esdeath"
	character_colors = [1, 2]
	universe = CharacterConcept.Universe.AKAME_GA_KILL
	description = "Esdeath, the strongest general in the Empire's army, and the appointed leader of the Jaegers. Her philosophy is simple: the strong deserve to live, and the weak are toys to be played with."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
