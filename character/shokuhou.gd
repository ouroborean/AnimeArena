extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Shokuhou Misaki"
	path_name = "shokuhou"
	universe = CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN
	character_colors = [2]
	description = "Shokuhou Misaki, the Majesty of Tokiwadai. The 5th ranked Esper of Academy City, with the most powerful mind control power on record, 'Mental Out'. Though she is the leader of the school's largest clique, her ability to compel others has left her personally isolated."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "shokuhou_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
