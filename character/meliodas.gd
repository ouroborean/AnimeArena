extends Character
class_name Meliodas


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [3]
	character_name = "Meliodas"
	path_name = "meliodas"
	universe = CharacterConcept.Universe.SEVEN_DEADLY_SINS
	description = "Meliodas, the captain of the Seven Deadly Sins and the Dragon's Sin of Wrath. Despite his appearance, Meliodas is ancient, and his experience leading the armies of demons and men have made him an unparalleled combatant."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
