extends Character
class_name Eren


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Eren Yeager"
	path_name = "eren"
	universe = CharacterConcept.Universe.ATTACK_ON_TITAN
	description = "Eren Yeager is a teenager who swears revenge against Titans who killed his mother and destroyed his hometown. During the Battle of Trost, Eren's impulsiveness and brash nature lead him to making a near-fatal mistake that revealed he can become a Titan."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
