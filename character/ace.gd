extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	character_name = "Portgas D. Ace"
	path_name = "ace"
	universe = CharacterConcept.Universe.ONE_PIECE
	description = 'The pirate known as "Fire Fist" Ace, wielder of the Mera Mera no Mi, is a proud and talented member of the Whitebeard Pirates. With a body made of fire and a fearsome stubbornness, Ace is a resilient fighter and a dangerous foe.'
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "ace_unlock" in player.unlocks

func _process(delta):
	pass
