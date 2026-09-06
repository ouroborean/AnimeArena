extends Character
class_name King



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	pass


func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "King"
	path_name = "king"
	universe = CharacterConcept.Universe.SEVEN_DEADLY_SINS
	description = "The Fairy King Harlequin, known simply as King, and the Grizzly's Sin of Sloth. King is the protector of the Fairy Realm, and wields his shape-shifting spear Chastiefol to rule over the cycle of life and death."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
