extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Uzumaki Boruto"
	character_colors = [1]
	path_name = "boruto"
	universe = CharacterConcept.Universe.NARUTO
	description = "Uzumaki Boruto, son of Naruto. Though similar in personality, Boruto's upbringing was the polar opposite of Naruto's: surrounded by friends, encouraged and nurtured by his doting parents, Boruto's talents as a shinobi are only matched by his pride and urge to prove himself."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "boruto_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
