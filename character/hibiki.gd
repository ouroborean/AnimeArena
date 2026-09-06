extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Hibiki Tachibana"
	path_name = "hibiki"
	character_colors = [0, 3]
	universe = CharacterConcept.Universe.SYMPHOGEAR
	description = "Hibiki Tachibana, wielder of the Symphogear Gungnir. With a shard of the relic fused to her heart, she throws herself into every fight with her bare fists and an unbreakable will to reach out and save others, no matter how many times she is knocked down."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "hibiki_unlock" in player.unlocks

func _process(delta):
	pass
