extends Character
class_name Hashirama


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Hashirama Senju"
	path_name = "hashirama"
	universe = CharacterConcept.Universe.NARUTO
	description = "The first Hokage, founder of the Leaf Village and God of Shinobi, Hashirama Senju. A shinobi of nearly unrivaled strength, the famous nemesis of Madara Uchiha boasts nearly limitless versatility and strength with his signature Wood-Style techniques. Thanks to: Hashirama Senju (lol)"
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
