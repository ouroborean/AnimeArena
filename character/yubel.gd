extends Character
class_name Yubel


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	


func initialize(_moveset = false):
	character_name = "Yubel"
	character_colors = [3, 2]
	universe = CharacterConcept.Universe.YUGIOH
	path_name = "yubel"
	description = "Yubel is a spirit-bonded Duel Monster from the Duel Academy era, devoted to Jaden Yuki to the point of obsession. Possessing the body of those who once swore to protect her, she manifests as a serpentine fiend whose love is inseparable from torment — every cruelty she inflicts is offered as proof of devotion."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
