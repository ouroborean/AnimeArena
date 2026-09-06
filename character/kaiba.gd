extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Seto Kaiba"
	path_name = "kaiba"
	universe = CharacterConcept.Universe.YUGIOH
	character_colors = [1, 2]
	description = "Seto Kaiba, wealthy owner of Kaiba Corp and talented duelist. Though he tends to wield his wealth as a cudgel to solve problems, he is also an undeniably skilled duelist, and one of the only true rivals of Yugi Mutou, the King of Games."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "kaiba_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
