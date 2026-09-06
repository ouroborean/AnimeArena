extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Asakura Yoh"
	character_colors = [0]
	universe = CharacterConcept.Universe.SHAMAN_KING
	path_name = "yoh"
	description = "Asakura Yoh, an easygoing teenage shaman who hopes to win the Shaman Fight so he can laze about the rest of his life. Partnered with the six-hundred-year-old samurai spirit Amidamaru, Yoh fuses his soul with his ally to wield the Halo Blade, trusting in his bonds and his ability to find peace amid any storm."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
