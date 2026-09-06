extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Hisoka Morow"
	path_name = "hisoka"
	character_colors = [2, 3]
	universe = CharacterConcept.Universe.HUNTER_X_HUNTER
	description = "Hisoka Morow, a pro hunter and former member of the Phantom Troupe. Hisoka is a fearsome fighter and insatiable killer, known to murder without a thought and to spare those he thinks might one day be enough to challenge him."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "hisoka_unlock" in player.unlocks

func _process(delta):
	pass
