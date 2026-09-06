extends Ability

# Spirit Gun (Rei Gun). Yusuke's basic blast + the Spirit Gun stack builder (max 2). USED at 2 stacks, it
# instead consumes the stacks and transforms this slot into Mega Spirit Gun (yusuke5). Empowered → Piercing.

func describe(user):
	return "Deals 20 damage to target enemy and gives Yusuke 1 stack of Spirit Gun (max 2). Deals 10 more damage per stack of Spirit Gun. When used at 2 stacks of Spirit Gun, instead consumes both stacks and transforms this skill into Mega Spirit Gun. While Empowered, deals Piercing damage."

func split_desc():
	return [
		"Deals 20 damage to target enemy and gains 1 stack of Spirit Gun (max 2)",
		["Deals 10 more damage per stack of Spirit Gun", Color.CADET_BLUE],
		["Used at 2 stacks: consumes both stacks and transforms into Mega Spirit Gun", Color.AQUAMARINE],
		["While Empowered: deals Piercing damage", Color.ORANGE_RED],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var empowered = user.marked_by("Empowered", user)
	var dtype = DamageType.Type.PIERCING if empowered else DamageType.Type.NORMAL
	# Base 20; the "Spirit Gun" DAMAGE_MOD on Yusuke adds +10 per stack (so a 2-stack cast still deals 40).
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 20, dtype)
	if empowered:
		user.effects.erase_effect(empowered)
	# Used AT 2 stacks -> transform + consume the stacks; otherwise gain a stack.
	if user.call_unique("yusuke", "spirit_gun_stacks", []) >= 2:
		user.call_unique("yusuke", "transform_to_mega", [context])
	else:
		user.call_unique("yusuke", "add_spirit_stack", [context, self, false])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 20)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
