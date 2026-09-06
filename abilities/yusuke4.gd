extends Ability

# Spirit Charge. Yusuke's setup skill: 35% DR, empower his next Harmful skill, and bank a stack of the
# currently-active gun. "Active gun" is the actual transform state (the Mega Mode ability-swap), NOT the
# Spirit Gun stack count — the transform now happens on USE, so 2 Spirit Gun stacks no longer imply Mega form.

func describe(user):
	return "Yusuke gains 35% damage reduction for 1 turn and Empowers his next Harmful skill. He also gains 1 stack of Spirit Gun, or Mega Spirit Gun if it is currently active."

func split_desc():
	return [
		"Yusuke gains 35% Damage Reduction for 1 turn",
		["Empowers his next Harmful skill", Color.AQUAMARINE],
		["Gains 1 stack of Spirit Gun, or Mega Spirit Gun if it is active", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.percent_dr(35, 2)   # 35% DR for 1 turn
	dr.set_source(self)
	Character.add_allied_effect(context, user, user, dr)
	var emp = Effect.mark(-1, "Yusuke's next Harmful skill is Empowered.")
	emp.name_override = "Empowered"
	emp.refresh = true   # re-casting Spirit Charge refreshes the single Empowered, never stacks a second
	emp.set_source(self)
	Character.add_allied_effect(context, user, user, emp)
	var mega = user.has_effect("Mega Mode", EffectType.Type.ABILITY_SWAP, user) != null
	user.call_unique("yusuke", "add_spirit_stack", [context, self, mega])

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
