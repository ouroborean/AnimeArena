extends Character
class_name Mavis


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_name = "Mavis Vermillion"
	character_colors = [2]
	universe = CharacterConcept.Universe.FAIRY_TAIL
	path_name = "mavis"
	description = "Mavis Vermillion, the First Master of the Fairy Tail guild and the architect of the Strategy of Holy Stars. From behind the safety of her allies, Mavis pulls every thread of the battlefield at once — coordinating her guild with calm clarity, and unleashing the three Great Magics of Fairy Tail when fate demands it."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
