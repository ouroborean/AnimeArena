extends Ability

# Spirit Gun (Rei Gun). Yusuke's basic blast + the Spirit Gun stack builder. At 2 stacks the character
# hub swaps this slot to Mega Spirit Gun (yusuke5). Empowered (from Spirit Charge) turns it Piercing.

func describe(user):
	return "Deals 20 damage to target enemy and gives Yusuke 1 stack of Spirit Gun. Deals 10 more damage per stack of Spirit Gun. At 2 stacks, this skill is replaced by Mega Spirit Gun. While Empowered, deals Piercing damage."

func split_desc():
	return [
		"Deals 20 damage to target enemy and gains 1 stack of Spirit Gun",
		["Deals 10 more damage per stack of Spirit Gun", Color.CADET_BLUE],
		["Replaced by Mega Spirit Gun at 2 stacks", Color.AQUAMARINE],
		["While Empowered: deals Piercing damage", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Empowered", user)
	var dtype = DamageType.Type.PIERCING if empowered else DamageType.Type.NORMAL
	# Base 20; the "Spirit Gun" DAMAGE_MOD on Yusuke adds +10 per stack through the engine. The stack is
	# granted AFTER this hit resolves, so the current cast is never boosted by its own new stack.
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, dtype)
	if empowered:
		user.effects.erase_effect(empowered)
	user.call_unique("yusuke", "add_spirit_stack", [context, self, false])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
