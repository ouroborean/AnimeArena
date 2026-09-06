extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Satoru Gojo"
	path_name = "gojo"
	character_colors = [1]
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	description = "Satoru Gojo, a special grade jujutsu sorceror and widely accepted to be the strongest in the world. With the use of his Infinity technique, he has total control over space and a nearly limitless amount of energy and power."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
