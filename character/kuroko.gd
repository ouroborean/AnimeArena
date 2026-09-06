extends Character
class_name Kuroko


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 3]
	character_name = "Shirai Kuroko"
	path_name = "kuroko"
	universe = CharacterConcept.Universe.A_CERTAIN_SCIENTIFIC_RAILGUN
	description = "Shirai Kuroko, level 4 esper and Misaka Mikoto's devoted underclassman. A talented member of Judgement, Academy City's organized esper task force, Kuroko puts her all into her work, constantly improving while maintaining a strict code of justice. Her ability to teleport both objects and herself make her an unpredictable foe."
	beginner = true
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
