extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Son Gohan"
	character_colors = [0, 2]
	path_name = "gohan"
	universe = CharacterConcept.Universe.DRAGON_BALL
	description = "Son Gohan, first child of Son Goku. Though he's only half-Saiyan, his strength surpassed that of his father when he was still a teenager. When his allies are hurt, an unbelievable latent power awakens in him."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "gohan_unlock" in player.unlocks

func _process(delta):
	pass
