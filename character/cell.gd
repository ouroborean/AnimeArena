extends Character
class_name Cell


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_colors = [0, 1]
	character_name = "Cell"
	path_name = "cell"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Cell, the Bio-Android assembled from the cells of every champion Gero could harvest. He fights as a curator of perfection, devouring the genetic record of his opponents to make his own form irreplaceable."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
