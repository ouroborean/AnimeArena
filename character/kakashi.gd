extends Character
class_name Kakashi


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):
	character_name = "Hatake Kakashi"
	description = "Hatake Kakashi, the Copy Ninja. A Jonin of the Hidden Leaf Village, Kakashi is the sensei of the notorious Team 7, and a man of nearly endless technical expertise and unpredictable jutsu."
	path_name = "kakashi"
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func is_unlocked(player):
	return "kakashi_unlock" in player.unlocks


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
