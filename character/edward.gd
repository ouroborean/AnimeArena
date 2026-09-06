extends Character
class_name Edward


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Edward Elric"
	path_name = "edward"
	universe = CharacterConcept.Universe.FULL_METAL_ALCHEMIST
	description = "Edward Elric, the Fullmetal Alchemist. After a brush with forbidden alchemy cost him an arm and a leg and his brother's entire body, Edward became a state alchemist with the goal of uncovering the secret of the Philosopher's Stone to bring back everything he's lost."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
