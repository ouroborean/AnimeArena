extends Character
class_name Tatsumi


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Tatsumi"
	path_name = "tatsumi"
	universe = CharacterConcept.Universe.AKAME_GA_KILL
	description = "Tatsumi, the newest member of Night Raid. Heading to the big city with dreams of fame and fortune, Tatsumi's dreams are quickly dashed as he is introduced to the darkness that lurks there. He decided to join Night Raid, a group of rebel assassins, to help make the country a safe and just place for all."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
