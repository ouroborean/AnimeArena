extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "All Might"
	path_name = "allmight"
	description = "All Might, the Symbol of Peace and the eighth wielder of One For All. Even with his power dwindling, he stands at the front and grins so the people behind him do not have to be afraid."
	character_colors = [1, 2, 3]
	universe = CharacterConcept.Universe.MY_HERO_ACADEMIA
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
