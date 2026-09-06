extends Character
class_name Itachi


func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)


func initialize(_moveset = false):
	character_name = "Uchiha Itachi"
	character_colors = [2, 3]
	universe = CharacterConcept.Universe.NARUTO
	path_name = "itachi"
	description = "Uchiha Itachi, the prodigy of the Uchiha clan and a member of the Akatsuki. A pacifist torn between his village and his family, he wields the Mangekyou Sharingan's three sacred techniques — Tsukuyomi, Amaterasu, and Susanoo — and a will sharp enough to play every side at once."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)


func is_unlocked(player):
	return true


func _process(delta):
	pass
