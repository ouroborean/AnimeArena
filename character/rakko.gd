extends Character
class_name Rakko


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_colors = [2]
	character_name = "Yumiya Rakko"
	path_name = "rakko"
	universe = CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN
	description = "Yumiya Rakko, a Hound Company sniper trained to hunt espers from outside their range. Patient and analytical, she opens engagements with a single bleeding round and lets the wound do the rest of the work."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
