extends Ability

# Owl Slash (hidden, base_abilities[5]). Swapped over Narukami Sword for 1 turn on every 3rd skill (by
# the SSS Ukaku Quinque passive). Deals 35 Piercing +5 per skill Arima has used this game; damage beyond
# the target's effective HP (overkill) becomes permanent Shield for Arima.
# Overkill has no engine read (resolve_damage returns nothing, HP clamps to 0), so it is computed here
# from pre-hit HP + shield + get_true_damage. Piercing is still absorbed by Shield in this engine.

func describe(user):
	return "Deals 35 Piercing damage to target enemy, increased by 5 for each skill Arima has used this game. Overkill damage is converted into permanent Shield for Arima."

func split_desc():
	return [
		"Deals 35 Piercing damage to target enemy",
		["Deals 5 more for each skill Arima has used this game", Color.CADET_BLUE],
		["Overkill damage becomes permanent Shield for Arima", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var counter = user.has_effect("SSS Ukaku Quinque", EffectType.Type.MARK, user)
	var used = counter.stack_count() if counter != null else 0
	var base = 35 + 5 * used
	for target in user.targeter.targets:
		# Overkill = post-mitigation damage beyond everything that could absorb it (Shield + Nullify barriers
		# + HP). resolve_damage returns nothing and clamps HP at 0, so it's computed here. Gated on an ACTUAL
		# kill: a hit fully blocked/absorbed (invuln, ignore-damage, Nullify, a survived shield) leaves the
		# target alive, so it grants no Shield.
		var pre_hp = target.health.hp
		var absorbers = 0
		for s in target.get_shield_effects():
			absorbers += s.mag
		for b in target.get_effects_by_type(EffectType.Type.BARRIER):
			absorbers += b.mag
		var dealt = min(get_true_damage(user, target, base, null, DamageType.Type.PIERCING), target.get_damage_cap_receive())
		Character.resolve_damage(context, target, base, DamageType.Type.PIERCING)
		if target.dead:
			var overkill = max(0, dealt - absorbers - pre_hp)
			if overkill > 0:
				var sh = Effect.shield_effect(overkill, -1)
				sh.set_source(self)
				Character.add_allied_effect(context, user, user, sh)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 40)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
