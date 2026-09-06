extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Lyserg Diethel"
	character_colors = [0, 3]
	universe = CharacterConcept.Universe.SHAMAN_KING
	path_name = "lyserg"
	description = "Lyserg Diethel, a young English shaman-detective who entered the Shaman Fight to avenge the parents he lost to Hao's fire. Armed with a dowsing pendulum and his fairy guardian Morphin, Lyserg tracks his marks with relentless precision, weighing his thirst for vengeance against the righteousness of the X-Laws."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
