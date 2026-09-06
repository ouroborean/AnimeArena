extends Character
class_name LaPucelle


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_name = "La Pucelle"
	path_name = "pucelle"
	description = "Kishibe Souta, the Magical Girl La Pucelle. As a boy, Souta often felt out of place due to his fascination with Magical Girls. He found a steady friendship in Himekawa Koyuki, and now that they are both Magical Girls, the two seek to live out their ideal lives, protecting the weak from harm."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return false
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
