extends Ability

func describe(user):
	return "Until the end of the turn, if target ally uses a new Strategic skill, they will become Immortal for 2 turns. This skill has bonus effects based on which Thompson Sister is active. Liz: if they use a new Helpful skill, their targets will heal 10 HP each turn for 2 turns. Patty: if they use a new Harmful skill, their next skill will deal 15 more non-Affliction damage."

func split_desc():
	return [
		"Until the end of the turn, if target uses a new Strategic skill, they become Immortal for 2 turns.",
		["If wielding Liz: if they use a new Helpful skill, its targets are healed 10 HP per turn for 2 turns.", Color.CADET_BLUE],
		["If wielding Patty: if they use a new Harmful skill, their next skill deals 15 more non-Affliction damage.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trig = Effect.trigger_effect(
			Trigger.always(resonance_trigger),
			EffectType.Type.ACTION_USE_TRIGGER,
			1,
			"If this character uses a new skill, Soul Resonance bonuses fire."
		)
		trig.set_source(self)
		Character.add_allied_effect(context, user, target, trig)

func resonance_trigger(context):
	var ally = context['owner']
	var thompson = user
	var used = context['source']
	if used == null:
		return

	if used.classes.has("Strategic") and used.classes["Strategic"]:
		var immortal = Effect.immortality_effect(4)
		immortal.set_source(self)
		Character.add_allied_effect(context, thompson, ally, immortal)

	
	var liz_active = ally.has_effect("Transform: Liz", EffectType.Type.HARMFUL_USE_TRIGGER)
	var patty_active = ally.has_effect("Transform: Patty", EffectType.Type.HARMFUL_USE_TRIGGER)

	# Death the Kid synergy (see kid5): Soul Resonance on Kid treats both
	# sisters as active, so both conditional branches can fire off his skills.
	if ally.path_name == "kid":
		liz_active = true
		patty_active = true

	if liz_active and used.classes.has("Helpful") and used.classes["Helpful"]:
		for hot_target in ally.targeter.targets:
			var hot = Effect.healing_effect(10, 4)
			hot.set_source(self)
			Character.add_allied_effect(context, thompson, hot_target, hot)

	if patty_active and used.classes.has("Harmful") and used.classes["Harmful"]:
		var dmg_boost = Effect.damage_mod_effect(15, -1, [], [], [DamageType.Type.AFFLICTION])
		dmg_boost.set_source(self)
		Character.add_allied_effect(context, thompson, ally, dmg_boost)

		var consume_trig = Effect.trigger_effect(
			Trigger.always(consume_patty_boost),
			EffectType.Type.DAMAGE_DEALT_TRIGGER,
			-1,
			"Will consume the Patty resonance bonus on next damage dealt."
		)
		consume_trig.set_source(self)
		consume_trig.invisible = true
		Character.add_allied_effect(context, thompson, ally, consume_trig)

func consume_patty_boost(context):
	var ally = context['owner']
	var trig_eff = context['effect']
	for eff in ally.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD):
		if eff.source == self:
			ally.effects.erase_effect(eff)
			break
	ally.effects.erase_effect(trig_eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
