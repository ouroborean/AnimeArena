extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sasuke Uchiha"
	character_colors = [1]
	universe = CharacterConcept.Universe.NARUTO
	path_name = "sasuke"
	description = "Uchiha Sasuke, last remaining member of the Uchiha clan. When his brother murdered his entire family in the dead of night, it set Sasuke on a path of vengeance that would take him to the heights and depths of the shinobi world."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
