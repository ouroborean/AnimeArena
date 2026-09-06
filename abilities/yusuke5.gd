extends Ability

# Mega Spirit Gun. The transformed slot-0 skill (swapped in by the hub once Spirit Gun hits 2 stacks).
# True damage that builds its own single stack. Empowered lets it fire through Invulnerability.

func describe(user):
	return "Deals 20 True damage to target enemy and gives Yusuke 1 stack of Mega Spirit Gun (max 1 stack). Deals 20 more damage per stack of Mega Spirit Gun. While Empowered, Bypasses Invulnerability."

func split_desc():
	return [
		"Deals 20 True damage to target enemy and gains 1 stack of Mega Spirit Gun (max 1)",
		["Deals 20 more damage per stack of Mega Spirit Gun", Color.CADET_BLUE],
		["While Empowered: Bypasses Invulnerability", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Empowered", user)
	# Base 20 True; the "Mega Spirit Gun" DAMAGE_MOD on Yusuke adds +20 per stack (max 1) through the engine.
	# The stack is granted AFTER this hit resolves, so the current cast is never boosted by its own new stack.
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, DamageType.Type.TRUE)
	if empowered:
		user.effects.erase_effect(empowered)
	user.call_unique("yusuke", "add_spirit_stack", [context, self, true])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	# While Empowered, target through Invulnerability (bypass is enforced at targeting).
	default_hostile_target_function(user, battle, user.marked_by("Empowered", user) != null)
