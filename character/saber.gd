extends Character
class_name Saber


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)
	moveset.base_abilities[0].cooldown_remaining = 2

func initialize(_moveset = false):

	character_colors = [0, 1]
	character_name = "Saber"
	universe = CharacterConcept.Universe.FATE
	path_name = "saber"
	description = "Saber, the Heroic Spirit Arturia Pendragon. The famous wielder of Excalibur, Saber has top notch combat and defensive abilities and can go toe-to-toe with nearly any combatant. Her powerful blade can demolish entire fortresses."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
