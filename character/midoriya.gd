extends Character
class_name Midoriya


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [0]
	character_name = "Midoriya Izuku"
	path_name = "midoriya"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "Although he was born Quirkless, Midoriya Izuku earned the right to wield the mantle of One For All through his innate heroism and strong sense of justice."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
