extends Character
class_name Koro


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Koro-sensei"
	path_name = "koro"
	universe = CharacterConcept.Universe.ASSASSINATION_CLASSROOM
	description = "Koro-sensei, an enigmatic alien creature. After destroying half of the moon and threatening the entire world, an uneasy Earth grants him his one request: to teach a class of troubled students the art of how to end a life. Thanks to: Fghop"
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
