extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Megumin"
	path_name = "megumin"
	character_colors = [3]
	universe = CharacterConcept.Universe.KONOSUBA
	description = "Megumin, the foremost archmage among Crimson Demons. Though her Explosion magic is dramatic and powerful, she will quickly find herself depleted and in need of allied support."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "megumin_unlock" in player.unlocks

func _process(delta):
	pass
