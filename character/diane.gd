extends Character
class_name Diane


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1]
	character_name = "Diane"
	path_name = "diane"
	universe = CharacterConcept.Universe.SEVEN_DEADLY_SINS
	description = "Diane, the Serpent's Sin of Envy. A member of the Giant Clan, she wields her Sacred Treasure Gideon together with her ability to control the earth to cause wide-spread havoc."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
