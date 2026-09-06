extends Character
class_name Soul


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 2]
	character_name = "Soul Evans"
	path_name = "soul"
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Soul Evans is a demon weapon born into a family of famous musicians. After discovering his weapon abilities, Soul joined Death Weapon Meister Academy where he partnered with the scythe-meister, Maka Albarn."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
