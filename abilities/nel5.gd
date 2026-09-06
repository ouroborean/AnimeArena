extends Ability

func describe(user):
	return "Whenever Nel spends energy on a skill, each ally other than Nel is healed for 5 HP per energy spent. Allies already at full HP gain 5 permanent Shield per energy spent instead. Doubled while Declare, Gamuza is active."

func split_desc():
	return [
		"Whenever Nel spends energy, each ally other than Nel is healed for 5 HP per energy spent.",
		["Allies at full HP gain 5 Shield per energy spent for 1 turn instead.", Color.DIM_GRAY],
		["Doubled while Declare, Gamuza is active.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trig = Effect.trigger_effect(
		Trigger.always(on_nel_uses_skill),
		EffectType.Type.ACTION_USE_TRIGGER,
		-1,
		"Nel's allies are healed when she spends energy.")
	trig.set_source(self)
	Character.add_allied_effect(context, user, user, trig)

func on_nel_uses_skill(context):
	var nel = context['effect'].user
	var ability = context['source']
	if ability == null or not (ability is Ability):
		return
	if ability.ability_name == "Cero Doble" and user.marked_by("Cero Doble"):
		return
	var spent = 0
	for etype in ability._cost.keys():
		spent += ability._cost[etype]
	if spent <= 0:
		return
	var per_energy = 5
	if nel.has_effect("Declare, Gamuza", EffectType.Type.MARK, nel):
		per_energy = 10
	var amount = int(per_energy * spent)
	for ally in context.ally_team.characters:
		if ally == nel:
			continue
		if ally.dead or ally.banished:
			continue
		if ally.health.hp >= ally.health.max_hp:
			var shield = Effect.shield_effect(amount, 2)
			shield.set_source(self)
			Character.add_allied_effect(context, nel, ally, shield)
		else:
			Character.resolve_healing(context, ally, amount)

func extra_usable(user):
	return true

func custom_behavior(context):
	return [[0, [user, "PASS", []]]]

func target(user, battle):
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
