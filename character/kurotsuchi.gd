extends Character
class_name Kurotsuchi


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_colors = [1, 2, 3]
	character_name = "Mayuri Kurotsuchi"
	path_name = "kurotsuchi"
	universe = CharacterConcept.Universe.BLEACH
	description = "Captain of the 12th Division and head of the Shinigami Research and Development Institute, Mayuri Kurotsuchi treats every fight as an experiment with himself as the only protected variable. A self-modifying scientist who measures victory in data harvested and contingencies survived, his cruelty is methodical — every dose, every banishment, every poison is calibrated to produce a more interesting outcome."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
