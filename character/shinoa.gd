extends Character
class_name Shinoa


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [3]
	character_name = "Hiragi Shinoa"
	path_name = "shinoa"
	universe = CharacterConcept.Universe.SERAPH_OF_THE_END
	description = "Shinoa Hiragi is a sergeant of the Japanese Imperial Demon Army and the leader of Shinoa Squad. Armed with Shikama Doji, a demon-possessed scythe, she leads her squad with sharp wit and tactical cunning."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "shinoa_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
