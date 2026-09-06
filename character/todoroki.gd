extends Character
class_name Todoroki


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1, 3]
	character_name = "Todoroki Shoto"
	path_name = "todoroki"
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	description = "Todoroki Shoto from UA's class 1-A. Son of the No. 2 hero Endeavor, he wields both fire and ice through his Half-Hot Half-Cold individuality. He balances both sides of his power to overwhelm opponents with either frozen barrages or blistering heat."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
