extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2, 3]
	character_name = "Rob Lucci"
	path_name = "rob"
	universe = CharacterConcept.Universe.ONE_PIECE
	description = "Rob Lucci, the 'Massacre Weapon' of Cipher Pol. Known amongst the organization as the strongest assassin in history, Rob's mastery over Rokushiki is unparalleled. With his Devil Fruit's power to transform him into a powerful leopard, Rob does the dirty work of the World Government with cold-blooded effectiveness."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
