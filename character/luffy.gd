extends Character
class_name Luffy


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
 

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Monkey D. Luffy"
	description = "Monkey D. Luffy, also known as 'Straw Hat Luffy', is the founder and captain of the increasingly infamous and powerful Straw Hat Pirates, as well as the most powerful of its top fighters. He believes that being the Pirate King means having the most freedom in the world. At age 7, Luffy accidentally ate the Gomu Gomu no Mi, which turned his body into rubber."
	beginner = true
	universe = CharacterConcept.Universe.ONE_PIECE
	path_name = "luffy"
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func _process(delta):
	pass
