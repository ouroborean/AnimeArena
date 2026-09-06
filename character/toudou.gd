extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Toudou Touka"
	path_name = "toudou"
	character_colors = [0]
	universe = CharacterConcept.Universe.CHIVALRY_OF_A_FAILED_KNIGHT
	description = "Toudou Touka, the heir to the Toudou-ryu school of swordsmanship. A prodigious fighter with a stoic exterior, Touka's lightning-fast draw is said to be able to cut down any opponent the moment they reveal an opening."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
