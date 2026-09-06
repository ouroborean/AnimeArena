extends Character
class_name Myotismon

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2, 3]
	character_name = "Myotismon"
	path_name = "myotismon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "Myotismon, the king of Undead Digimon. Originally a computer virus, Myotismon is a malignant and extremely cruel Digimon who uses his dark powers to debilitate his foes and extend his own unnatural life."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
