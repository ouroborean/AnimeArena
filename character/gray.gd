extends Character
class_name Gray


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Gray Fullbuster"
	path_name = "gray"
	universe = CharacterConcept.Universe.FAIRY_TAIL
	description = "Gray Fullbuster, ice mage of Fairy Tail. Natsu's number one rival, Gray is a cool and collected mage that uses ice moulding magic to craft wondrous creations from ice."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
