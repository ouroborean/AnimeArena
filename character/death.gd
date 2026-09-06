extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Death"
	path_name = "death"
	universe = CharacterConcept.Universe.SOUL_EATER
	character_colors = [0, 1, 2, 3]
	description = "Death, the Shinigami and founder of the DWMA. To seal away the first Kishin he anchored his own soul to Death City, trading his freedom of movement for an unbreakable vigil. The Grim Reaper meets every threat to the world's order with overwhelming, inevitable force."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "death_unlock" in player.unlocks

func _process(delta):
	pass
