extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Power"
	character_colors = [3]
	universe = CharacterConcept.Universe.CHAINSAW_MAN
	path_name = "power"
	description = "The Blood Fiend — a devil in human form, loud, vain, and gleefully violent. Power weaponizes blood itself, hurling it as blades and spears, feasting on every wound she opens, and turning the enemy's own bleeding into a bludgeon."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "power_unlock" in player.unlocks

func _process(delta):
	pass
