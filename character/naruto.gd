extends Character
class_name Naruto



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func startup(nbattle):
	battle = nbattle
	initialize()
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1, 2]
	character_name = "Naruto Uzumaki"
	path_name = "naruto"
	universe = CharacterConcept.Universe.NARUTO
	description = "Naruto is known for his boisterous personality, unwavering determination, and dream of becoming the Hokage. Despite being ostracized for having the Nine-Tailed Fox sealed within him, he remains optimistic and seeks recognition from his peers. Naruto's main techniques during this period include the Shadow Clone Jutsu and the Rasengan."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func _process(delta):
	pass
