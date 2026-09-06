extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Marco the Phoenix"
	character_colors = [1, 2]
	path_name = "marco"
	universe = CharacterConcept.Universe.ONE_PIECE
	description = "Marco the Phoenix, former commander of the 1st Division of the Whitebeard Pirates. Using the power of the Hito Hito no Mi, Marco can transform into a nearly immortal phoenix, fighting on par with Admirals or healing the injured with his blue flames."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "marco_unlock" in player.unlocks

func _process(delta):
	pass
