extends Character
class_name Nezuko


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2]
	character_name = "Kamado Nezuko"
	path_name = "nezuko"
	universe = CharacterConcept.Universe.DEMON_SLAYER
	description = "Kamado Nezuko is the younger sister of Tanjiro and a demon herself, though she retains her human emotions and consciousness. After being turned into a demon by a powerful demon, Nezuko struggles to maintain her humanity and resist the urge to feed on humans."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
