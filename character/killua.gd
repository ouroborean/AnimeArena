extends Character
class_name Killua


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset=false):

	character_colors = [0]
	character_name = "Killua Zoldyck"
	path_name = "killua"
	universe = CharacterConcept.Universe.HUNTER_X_HUNTER
	description = "A highly skilled assassin and a close friend of Gon, Killua Zoldyck is a complex and enigmatic young man. Trained since birth to be a lethal killer, Killua possesses incredible NORMAL and mental abilities that make him a formidable opponent. Despite his past, he befriends Gon and learns to value friendship and loyalty above all else."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
