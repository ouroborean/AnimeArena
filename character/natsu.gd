extends Character
class_name Natsu


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Natsu Dragneel"
	path_name = "natsu"
	universe = CharacterConcept.Universe.FAIRY_TAIL
	description = "Natsu Dragneel, infamous fire mage of Fairy Tail. He was raised by a dragon, Igneel, who taught him dragon-slaying magic that he wields with a pure heart and a quick temper."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
