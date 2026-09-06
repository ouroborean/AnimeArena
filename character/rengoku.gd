extends Character
class_name Rengoku


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 3]
	character_name = "Kyojuro Rengoku"
	path_name = "rengoku"
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "A Hashira of the Demon Slayer Corps, Rengoku is a eccentric yet enthusiastic swordsman, who harnesses his Flame Breathing style for devastating swordplay."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "rengoku_unlock" in player.unlocks

func _process(delta):
	pass
