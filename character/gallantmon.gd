extends Character
class_name Gallantmon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	var context = QueryContext.from_game_state(self, battle)

func initialize(_moveset = false):

	character_colors = [0, 3]
	character_name = "Gallantmon"
	path_name = "gallantmon"
	universe = CharacterConcept.Universe.DIGIMON
	description = "Gallantmon, one of the 13 Royal Knights. Tasked with defending the digital world from the 7 Demon Lords, Gallantmon wields its shield and spear to protect the weak and to eradicate evil wherever it exists."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)
		moveset.base_abilities[1].counter_response_trigger = spear_counter_response

func spear_counter_response(target):
	var context = QueryContext.from_game_state(self, battle)
	var swap_eff = Effect.ability_swap_effect(4, 1, self, 3)
	swap_eff.set_source(moveset.base_abilities[1])
	Character.add_allied_effect(context, self, self, swap_eff)
	
func is_unlocked(player):
	return "gallantmon_unlock" in player.unlocks

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
