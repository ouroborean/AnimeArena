extends Character
class_name Sakura


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2, 3]
	character_name = "Haruno Sakura"
	path_name = "sakura"
	universe = CharacterConcept.Universe.NARUTO
	description = "Sakura is often seen as having a sharp intellect, excellent chakra control, and a deep admiration for Sasuke Uchiha. Initially perceived as having a more supportive role, her training under the Fifth Hokage, Tsunade, elevates her combat abilities, particularly in the area of medical ninjutsu and superhuman strength."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
