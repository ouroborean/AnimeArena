extends Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2]
	character_name = "Arthur Boyle"
	universe = CharacterConcept.Universe.FIRE_FORCE
	path_name = "arthur"
	description = "A Third Generation pyrokinetic of Company 8 and the self-styled Knight King. Convinced of his own chivalric legend, Arthur's delusions are not madness but fuel — the harder he believes, the sharper his Plasma blade cuts, splitting the very moon."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
