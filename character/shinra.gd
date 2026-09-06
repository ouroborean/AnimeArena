extends Character
class_name Shinra


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Shinra Kusakabe"
	path_name = "shinra"
	universe = CharacterConcept.Universe.FIRE_FORCE
	description = "Shinra Kusakabe is a pyrokinetic in the Special Fire Force Company 8. Shinra wants to become a hero, protecting the innocent from Spontaneous Human Combustion with the power of his own flames."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
