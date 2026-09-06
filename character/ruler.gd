extends Character
class_name Ruler


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_name = "Ruler"
	path_name = "ruler"
	description = "Sanae Mukou, a woman who spent her entire life being ostracized for her intellect and browbeat by incompetent authority, received the opportunity to become the Magical Girl Ruler. Using her power to issue commands that must be obeyed, she has gathered a cluster of easily manipulated magical girls to her side."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return false
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
