extends Character
class_name SnowWhite


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_name = "Snow White"
	path_name = "snowwhite"
	description = "Himekawa Koyuki, the magical girl Snow White. A loving, selfless girl who was drawn into a game of death by a sadistic magical girl. She can hear the thoughts of those in distress, and can use this to aid allies or get the upper hand on enemies."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return false
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
