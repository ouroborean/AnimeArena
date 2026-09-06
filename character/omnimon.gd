extends Character
class_name Omnimon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1, 3]
	character_name = "Omnimon"
	path_name = "omnimon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "One of the Royal Knights, a Digimon created for the singular purpose of defeating the Demon Lords. A fusion of WarGreymon and MetalGarurumon, Omnimon combines the strengths of both Digimon into a formidable duelist. Thanks to: Kiru Kasai"
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
