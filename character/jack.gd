extends Character
class_name Jack


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 2]
	character_name = "Jack the Ripper"
	path_name = "jack"
	universe = CharacterConcept.Universe.FATE
	description = "Jack the Ripper, a Heroic Spirit summoned in the role of Assassin. Jack is an embodiment of the vengeful spirits of the lost and neglected children who died on the streets of London. She can call forth London's bleak smog and steal her enemies away to its cold streets."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
