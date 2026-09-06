extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Tsubaki Nakatsukasa"
	path_name = "tsubaki"
	character_colors = [3]
	universe = CharacterConcept.Universe.SOUL_EATER
	description = "Tsubaki Nakatsukasa, a talented Demon Weapon and the devoted partner of Black Star. She can change into a variety of different weapon forms to fit the situation, a rarity among Weapons."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
