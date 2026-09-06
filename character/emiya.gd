extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Emiya Shirou"
	character_colors = [3]
	path_name = "emiya"
	universe = CharacterConcept.Universe.FATE
	description = "Emiya Shirou, a young mage thrust unwillingly into a Holy Grail War. His magic lets him trace the properties of other artifacts, reinforcing the mundane and even conjuring copies of enemy weapons."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
