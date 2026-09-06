extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2]
	character_name = "Trafalgar Law"
	path_name = "law"
	universe = CharacterConcept.Universe.ONE_PIECE
	description = 'Trafalgar D. Water Law, the "Surgeon of Death" and captain of the Heart Pirates. With the Ope Ope no Mi he raises a ROOM and rearranges everything inside it — swapping positions, cutting without a wound, and turning his enemies\' own strikes against their allies.'
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "law_unlock" in player.unlocks

func _process(delta):
	pass
