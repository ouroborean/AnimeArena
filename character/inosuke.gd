extends Character
class_name Inosuke


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Hashibira Inosuke"
	path_name = "inosuke"
	character_colors = [0, 2]
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "Hashibira Inosuke, the wild and uncontrollable beast man. From his trademark boar helmet to his chipped and jagged blades, everything about Inosuke is hazardous and free."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
