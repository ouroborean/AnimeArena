extends Character
class_name BlackStar


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 2]
	character_name = "Black Star"
	path_name = "blackstar"
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "An assassin who loves the spotlight, Black Star is one of the top Maesters of the DWMA, along with his partner, Tsubaki Nakatsukasa."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "blackstar_unlock" in player.unlocks

func _process(delta):
	pass
