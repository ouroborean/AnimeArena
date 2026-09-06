extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Baki Hanma"
	path_name = "baki"
	universe = CharacterConcept.Universe.BAKI
	description = "Baki Hanma is the champion of an underground fighting circuit in Japan. Known as \"The Strongest Boy on Earth,\" he is a martial artist who trains relentlessly in pursuit of the goal of surpassing his father, Yujiro."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "baki_unlock" in player.unlocks

func _process(delta):
	pass
