extends Character
class_name Ryohei


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [3]
	character_name = "Ryohei Sasagawa"
	path_name = "ryohei"
	universe = CharacterConcept.Universe.KATEKYO_HITMAN_REBORN
	description = "Sasagawa Ryohei, the Vongola Guardian of the Sun. Ryohei is an exuberant, if slightly oblivious, member of Sawada Tsunayoshi's growing Mafia family. An avid boxer, his motto is to live 'to the extreme!', which is something that he extends to all facets of life. He immediately and enthusiastically wants to be included in anything he sees."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
