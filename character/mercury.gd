extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sailor Mercury"
	path_name = "mercury"
	character_colors = [1]
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Sailor Mercury, also known as Ami Mizuno, is the brain of the Sailor Guardians, possessing an incredible IQ and a calm, analytical nature. Despite her shy demeanor, her unwavering dedication to her friends and her dream of becoming a doctor make her a vital pillar of the team."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
