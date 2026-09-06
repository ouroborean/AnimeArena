extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Asui Tsuyu"
	character_colors = [0]
	path_name = "tsuyu"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "Asui Tsuyu, the Rainy Season Hero: Froppy. A compassionate and cooperative girl, her Quirk, Frog, lets her do anything a frog can do."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "tsuyu_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
