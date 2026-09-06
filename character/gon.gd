extends Character
class_name Gon


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

	character_colors = [0, 1]
	character_name = "Gon Freecs"
	universe = CharacterConcept.Universe.HUNTER_X_HUNTER
	description = "Gon Freecss, known for his unwavering determination and boundless potential, has faced countless challenges in his journey as a Hunter. Using his unique capacity for Nen, Gon utilizes his own Janken-style fighting technique to overwhelm his enemies."
	beginner = true
	path_name = "gon"
	
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func example_passive_startup_function(context):
	pass

func _process(delta):
	pass
