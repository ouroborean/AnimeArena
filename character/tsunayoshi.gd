extends Character
class_name Tsuna


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_colors = [1]
	character_name = "Sawada Tsunayoshi"
	path_name = "tsunayoshi"
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	description = "Sawada Tsunayoshi, the tenth head of the Vongola Family. Unconfident and timid, yet fiercely loyal to his friends, Tsuna is the unwilling head of a mafia family, and wielder of the Vongola Flames of the Sky."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
