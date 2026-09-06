extends Character
class_name Sheele


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2, 3]
	character_name = "Sheele"
	path_name = "sheele"
	universe = CharacterConcept.Universe.AKAME_GA_KILL
	description = "Sheele, an assassin of Night Raid. A compassionate woman who, in a moment of life-threatening danger, discovered she had a talent for murder. She wields Extase, a pair of giant scissors that can cut through anything."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
