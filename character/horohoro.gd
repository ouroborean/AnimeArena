extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Horohoro"
	character_colors = [1]
	universe = CharacterConcept.Universe.SHAMAN_KING
	path_name = "horohoro"
	description = "Horohoro, an Ainu shaman who competes in the Shaman Fight to win back the lands stolen from his people and create a vast coltsfoot field for the Koropokkuru. Partnered with the ice spirit Kororo, he channels biting winter winds and jagged icicles with a snowboard he treats as both weapon and stage."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
