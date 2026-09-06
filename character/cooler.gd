extends Character
class_name Cooler


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_colors = [0, 1, 3]
	character_name = "Cooler"
	path_name = "cooler"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Cooler, the elder brother of Frieza and an Armored Squadron commander whose patience and pride run deeper than his sibling's tantrums. A perfectionist conqueror who treats every opponent as an experiment in calibrated cruelty — strike them with what they can survive, then make sure they can never recover."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
