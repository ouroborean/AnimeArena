extends Character
class_name Saitama


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


func startup(nbattle):
	battle = nbattle
	battle.connect_character(self)
	

func initialize(_moveset = false):

	character_colors = [0]
	character_name = "Saitama"
	path_name = "saitama"
	universe = CharacterConcept.Universe.ONE_PUNCH_MAN
	description = "Saitama is the titular One Punch Man. As the current strongest known being in the universe, he has lost all joy and meaning since the only wish he has is to have a good fight."
	if _moveset:
		moveset.set_base_abilities(Movesets.from_skill_count(self), self)

func swap_trigger(context):
	var swapped = Condition.has_effect(self, "Normal Punch", EffectType.Type.ABILITY_SWAP, self)
	if swapped.satisfied(context):
		effects.remove_effect("Normal Punch", EffectType.Type.ABILITY_SWAP, self)
	else:
		var swap = Effect.ability_swap_effect(4, 0, self, 3)
		swap.set_source(moveset.base_abilities[0])
		Character.add_allied_effect(context, self, self, swap)

func is_unlocked(player):
	return true
	#return player.mission_complete("character_unlock_mission")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
