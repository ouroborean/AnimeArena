extends Character
class_name Kitara


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1]
	character_name = "Katara"
	path_name = "kitara"
	universe = CharacterConcept.Universe.AVATAR
	description = "A Waterbender from the Southern Water Tribe. Katara fights alongside the Avatar and commands water in every form — from slicing waves to deflecting ice and mending wounds."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
