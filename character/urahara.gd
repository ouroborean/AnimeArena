extends Character
class_name Urahara


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):
	character_name = "Urahara Kisuke"
	path_name = "urahara"
	description = "Urahara Kisuke is the former captain of the 12th Division of the Court Guard Squards. He currently resides in Karakura Town, where he runs a shop that sells Shinigami supplies."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
