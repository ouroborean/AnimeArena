extends Character

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Hibari Kyouya"
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	path_name = "hibari"
	description = "The fearsome leader of the Namimori Disciplinary Committee and the Vongola Famiglia's Cloud Guardian. A lone wolf who answers to no one, Hibari drifts at the edge of the family like a cloud — and bites to death anyone who disturbs the peace of Namimori."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
