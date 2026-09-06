extends Character
class_name Uraraka


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	#Call passive startup functions here
	#example_passive_startup_function(context)

func initialize(_moveset=false):

	character_colors = [0, 2]
	character_name = "Uraraka Ochaco"
	path_name = "uraraka"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "A skilled fighter and member of the U.A. High School's Hero Course, Uraraka is a cheerful and optimistic young woman with a heart of gold. Her Quirk, Zero Gravity, allows her to manipulate gravity, making objects weightless with a touch."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func example_passive_startup_function(context):
	pass

func _process(delta):
	pass
