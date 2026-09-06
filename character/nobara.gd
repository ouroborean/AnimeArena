extends Character



# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 1]
	character_name = "Kugisaki Nobara"
	path_name = "nobara"
	universe = CharacterConcept.Universe.JUJUTSU_KAISEN
	description = "Nobara is a first year sorceror studying alongside Itadori Yuji. Her special technique involves linking a doll to her enemy and channeling her cursed energy through her hammer and nails."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
