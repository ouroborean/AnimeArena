extends Character


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	moveset.base_abilities[1].modifier_value = 2
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):
	character_name = "Ban"
	character_colors = [2]
	path_name = "ban"
	universe = CharacterConcept.Universe.SEVEN_DEADLY_SINS
	description = "Undead Ban, the Fox's Sin of Greed. With his unique ability to 'rob' his targets of their strength, combined with the immortality he gained from the Fountain of Youth, Ban is a terrifying and unstoppable fighter."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
	
func is_unlocked(player):
	return "ban_unlock" in player.unlocks
	#return player.mission_complete("character_unlock_mission")

func _process(delta):
	pass
