extends Ability

func describe(user):
	if user and user.has_effect("Constant Resounding Slashes", EffectType.Type.MARK):
		return "Deals 15 Piercing damage to target enemy and gives Tengen 5 Damage Reduction for 1 turn."
	return "Deals 30 Piercing damage to target enemy and gives Tengen 10 Damage Reduction for 1 turn. Next turn, this skill has half effect but costs 1 Random energy."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy and gives Tengen 10 Damage Reduction for 1 turn",
		["Next turn, this skill has half effect but costs 1 Random energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var half_mark = user.has_effect("Constant Resounding Slashes", EffectType.Type.MARK)
	var damage = 30
	var dr = 10
	if half_mark:
		damage = 15
		dr = 5
		user.effects.erase_effect(half_mark)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
	var dr_eff = Effect.damage_reduction_effect(dr, 2)
	dr_eff.set_source(self)
	Character.add_allied_effect(context, user, user, dr_eff)
	if not half_mark:
		var mark = Effect.mark(3, "Constant Resounding Slashes will have half effect but cost 1 Random energy.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
		var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Constant Resounding Slashes"])
		cost_change.set_source(self)
		Character.add_allied_effect(context, user, user, cost_change)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
