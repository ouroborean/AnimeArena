extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "LadyDevimon"
	path_name = "ladydevimon"
	description = "LadyDevimon, a Fallen Angel Digimon whose blackened wings drip with venom. She turns every blow against her into a slow, agonizing curse on whoever dared to strike her."
	character_colors = [1, 3]
	universe = CharacterConcept.Universe.DIGIMON
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
