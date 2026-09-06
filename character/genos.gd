extends Character
class_name Genos


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [1, 2]
	character_name = "Genos"
	path_name = "genos"
	universe = CharacterConcept.Universe.ONE_PUNCH_MAN
	description = "Genos, the Rank-12 S Class Hero Demon Cyborg. Apprenticed to Saitama, Genos is an advanced fighting machine capable of unleashing blisteringly fast attacks and overwhelming energy assaults."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
