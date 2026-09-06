extends Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Toph Beifong"
	path_name = "toph"
	character_colors = [0]
	universe = CharacterConcept.Universe.AVATAR
	description = "Toph Beifong, one of the most powerful earthbenders of her time. Despite being born blind, she acts with startling precision using her sense of touch and her earthbending prowess."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
