extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Sailor Venus"
	path_name = "venus"
	character_colors = [3]
	universe = CharacterConcept.Universe.SAILOR_MOON
	description = "Minako Aino is the Sailor Guardian of Love and Beauty, known as Sailor Venus. As the leader of the Inner Senshi and a skilled combatant, she uses her radiant attacks and chain whip to dazzle enemies and protect her allies."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
