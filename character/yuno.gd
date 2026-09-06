extends Character
class_name Yuno


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [1]
	universe = CharacterConcept.Universe.BLACK_CLOVER
	character_name = "Yuno Grinberryall"
	path_name = "yuno"
	description = "Yuno is an orphan left at a church after the downfall of his family, the rulers of the Spade Kingdom. Along with his partner, the wind spirit Sylph, Yuno wields his four-leaf clover grimoire in service of the Royal Knights."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
		moveset.base_abilities[6].counter_response_trigger = counter_response


func counter_response(target):
	used_ability.delay_execution(self, self.battle, 1)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
