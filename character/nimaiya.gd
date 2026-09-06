extends Character
class_name Nimaiya


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [2]
	character_name = "Nimaiya Oetsu"
	path_name = "nimaiya"
	universe = CharacterConcept.Universe.BLEACH
	description = "The God of the Sword, Divine General of the West, Third Officer of the Zero Division and the creator of Zanpakutou, Nimaiya Oetsu sits at the pinnacle of swordsmanship. His blade Sayafushi is so sharp that it has been deemed a failure as a zanpakutou, though he wields it to deadly effect."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "nimaiya_unlock" in player.unlocks

func _process(delta):
	pass
