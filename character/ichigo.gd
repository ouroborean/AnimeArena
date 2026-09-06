extends Character
class_name Ichigo


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [1, 3]
	character_name = "Ichigo Kurosaki"
	path_name = "ichigo"
	universe = CharacterConcept.Universe.BLEACH
	description = "Ichigo is a substitute Shinigami who initially borrowed Rukia's power. Since then, Ichigo has unlocked and learned how to use his sword Zangetsu while developing a close bond with him."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
