extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Death the Kid"
	path_name = "kid"
	character_colors = [0, 1]
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Death the Kid, son of the Grim Reaper. A neurotic and symmetry-obsessed young meister, Kid's powers as a fledgling reaper are only just beginning to manifest."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "kid_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
