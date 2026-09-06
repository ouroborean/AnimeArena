extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)

func initialize(_moveset = false):
	character_name = "Yoruichi Shihouin"
	path_name = "yoruichi"
	universe = CharacterConcept.Universe.BLEACH
	character_colors = [2]
	description = "Yoruichi Shihouin, the Flash Goddess. Former captain of the Second Division and commander of the Onmitsukido, she abandoned the Soul Society rather than her own principles. She fights bare-handed and impossibly fast, wrapping herself in the lightning of Shunko and making every swing an enemy takes cost them the tempo of the fight."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
