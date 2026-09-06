extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Renamon"
	character_colors = [0, 1, 2]
	universe = CharacterConcept.Universe.DIGIMON
	path_name = "renamon"
	description = "This vulpine Digimon is a refined and agile fighter. Renamon specializes in high-speed combat, often utilizing its agility and illusionary techniques to confuse opponents before delivering a decisive blow."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
