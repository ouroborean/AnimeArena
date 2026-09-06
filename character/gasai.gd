extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Yuno Gasai"
	path_name = "gasai"
	universe = CharacterConcept.Universe.MIRAI_NIKKI
	character_colors = [0, 2, 3]
	description = "The Yandere. Armed with her Future Diary and a devotion to Yukiteru Amano that borders on madness, Yuno Gasai will cut down anyone who threatens him - reading their every move, deflecting their strikes, and answering each attack with an axe."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

func _process(delta):
	pass
