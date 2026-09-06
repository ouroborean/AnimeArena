extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Fushiguro Megumi"
	path_name = "megumi"
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	character_colors = [3]
	description = "Fushiguro Megumi, a jujutsu sorceror who summons shadow spirits to do his bidding. With a versatile array of various puppets, Megumi can adapt to a variety of situations."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true

func _process(delta):
	pass
