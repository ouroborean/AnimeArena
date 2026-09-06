extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "EMIYA"
	character_colors = [0, 3]
	universe = CharacterConcept.Universe.FATE
	path_name = "emiyaarcher"
	description = "EMIYA, an Archer-class Servant with no history. An enigma even among the Heroic Spirits, EMIYA possesses an arsenal of powerful artifacts and an unerring knowledge of other Heroic Spirits and their Noble Phantasms. When combined with his own ferocity and sharp battle acumen, EMIYA is a powerful and unpredictable foe."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "emiyaarcher_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
