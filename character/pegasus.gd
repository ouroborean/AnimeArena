extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Maximillion Pegasus"
	path_name = "pegasus"
	character_colors = [0, 1]
	universe = CharacterConcept.Universe.YUGIOH
	description = "Maximillion Pegasus, creator of Duel Monsters and host of the Duelist Kingdom tournament. With the power of the Millennium Eye, Pegasus reads his opponent's mind and traps them in shifting illusions, binding their strongest moves until they bend to his will."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
