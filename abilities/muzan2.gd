extends Ability

# Blood Demon Art: Assimilation. The heavier Blood Gash — 35 up front and a 5/turn tail for 3 turns,
# damage or heal. Same Lab Experiment consumption.

func describe(user):
	return "Deals 35 Bleed damage to target enemy, then 5 Bleed damage per turn for 3 turns, or heals target ally 35 HP, then 5 HP per turn for 3 turns."

func split_desc():
	return [
		"Enemy: 35 Bleed now, then 5 Bleed per turn for 3 turns",
		"Ally: heals 35 now, then 5 HP per turn for 3 turns",
		["Lab Experiment stacks add +10 to the immediate hit, then are consumed", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bonus = 0
	var boost = user.has_effect("Lab Experiment", EffectType.Type.MARK, user)
	if boost:
		bonus = boost.stack_count() * 10
	for target in user.targeter.targets:
		if target in user.team.characters:
			Character.resolve_healing(context, target, 35 + bonus)
			var hot = Effect.healing_effect(5, 7)   # dur 7 = ticks on Muzan's next 3 turns
			hot.set_source(self)
			hot.refresh = true   # reapplying refreshes rather than stacking a second HoT
			Character.add_allied_effect(context, user, target, hot)
		else:
			Character.resolve_damage(context, target, 35 + bonus, DamageType.Type.BLEED)
			var dot = Effect.damage_effect(5, DamageType.Type.BLEED, 7)
			dot.set_source(self)
			dot.refresh = true   # reapplying refreshes rather than stacking a second bleed
			Character.add_hostile_effect(context, user, target, dot)
	if boost:
		user.effects.remove_effect("Lab Experiment", EffectType.Type.MARK, user)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 70)
	variations += behavior_single_target_helpful(context, 45)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
