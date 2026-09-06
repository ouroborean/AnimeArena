extends Character
class_name Lucy


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2]
	character_name = "Lucy Heartphilia"
	path_name = "lucy"
	universe = CharacterConcept.Universe.FAIRY_TAIL
	description = "Lucy Heartfilia, proud Celestial Spirit wizard of Fairy Tail. After a chance meeting with Natsu Dragneel, Lucy joined his guild and started a life of adventure. As a Celestial Spirit wizard, Lucy uses Zodiac Keys to summon outsiders to fight with her."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
