extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Escanor"
	path_name = "escanor"
	character_colors = [1, 3]
	universe = CharacterConcept.Universe.SEVEN_DEADLY_SINS
	description = "Escanor, the Lion's Sin of Pride of the Seven Deadly Sins. His magic, Sunshine, swells without limit as the day wears on — until at high noon 'The One' stands as the mightiest being alive. Every stack of Sunshine he gathers makes his pride, and his power, burn hotter."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "escanor_unlock" in player.unlocks

func _process(delta):
	pass
