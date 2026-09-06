extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "The Thompson Sisters"
	path_name = "lizandpatty"
	character_colors = [1, 0]
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Liz and Patty Thompson are demon weapon sisters from Brooklyn. Originally a pair of mugger pistols who terrorized the streets, they were taken in by Death the Kid and became his Demon Twin Guns. They share a single body, switching between Liz and Patty as the active sister."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
