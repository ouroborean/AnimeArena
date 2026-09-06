extends Character
class_name Ryuko


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 3]
	character_name = "Ryuko Matoi"
	path_name = "ryuko"
	universe = CharacterConcept.Universe.KILL_LA_KILL
	description = "Ryuko Matoi, a hybrid human fused with Life Fibers. Bearing one half of a red Scissor Blade, Ryuko searches for the person bearing the other half, who used that weapon to murder her father."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
