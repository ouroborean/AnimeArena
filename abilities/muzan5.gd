extends Ability

# King of Blood (PASSIVE). Two effects, wired as permanent triggers at battle start (startup_passives):
#   1. Muzan heals 5 whenever he DEALS Bleed damage (DAMAGE_DEALT_TRIGGER filtered to BLEED) or GIVES
#      healing to another character (HEALING_GIVEN_TRIGGER; self-heals — including this very +5 — are
#      excluded so it can't loop).
#   2. Whenever a character carrying one of Muzan's bleed (BLEED DAMAGE) or heal-over-time (HEALING)
#      effects uses a skill, those effects gain +1 turn (+2 duration). Implemented as an ACTION_USE
#      watcher seeded on every character; it no-ops on anyone not currently carrying a Muzan effect.
# The heals go through resolve_effect_healing (sourced from this passive), NOT resolve_healing, so they
# do not depend on Muzan's used_ability mid-trigger.

func describe(user):
	return "Whenever Muzan deals Bleed damage or heals an ally, he heals 5 HP. Whenever a character affected by his bleed or heal over time effects uses a skill, those effects increase their durations by 1 turn."

func split_desc():
	return [
		"Muzan heals 5 HP whenever he deals Bleed damage or heals an ally",
		"When a character carrying his bleed / heal-over-time uses a skill, those effects last 1 turn longer",
	]

func execute(user, battle):
	# startup_passives runs this exactly once, but guard against any future re-init double-seeding the
	# triggers (which would double Muzan's self-heal and the +2 duration extensions).
	if user.has_effect("King of Blood", EffectType.Type.DAMAGE_DEALT_TRIGGER, user) != null:
		return
	var context = QueryContext.from_game_state(user, battle)

	var bleed_heal = Effect.trigger_effect(
		Trigger.always(on_bleed_dealt), EffectType.Type.DAMAGE_DEALT_TRIGGER, -1,
		"Muzan heals 5 HP whenever he deals Bleed damage.")
	_permanent(bleed_heal)
	Character.add_allied_effect(context, user, user, bleed_heal)

	var heal_heal = Effect.trigger_effect(
		Trigger.always(on_heal_given), EffectType.Type.HEALING_GIVEN_TRIGGER, -1,
		"Muzan heals 5 HP whenever he heals an ally.")
	_permanent(heal_heal)
	Character.add_allied_effect(context, user, user, heal_heal)

	for c in battle.all_characters():
		var watcher = Effect.trigger_effect(
			Trigger.always(on_affected_acts), EffectType.Type.ACTION_USE_TRIGGER, -1, "")
		_permanent(watcher)
		if c in user.team.characters:
			Character.add_allied_effect(context, user, c, watcher)
		else:
			Character.add_hostile_effect(context, user, c, watcher, true)

func _permanent(eff):
	eff.system = true
	eff.invisible = true
	eff.remove_on_death = false
	eff.set_source(self)

func on_bleed_dealt(context):
	if context.damage_type != DamageType.Type.BLEED:
		return
	var muzan = context['effect'].user
	if muzan.dead or muzan.banished:
		return
	Character.resolve_effect_healing(context, context['effect'], muzan, 5)

func on_heal_given(context):
	var muzan = context['effect'].user
	if muzan.dead or muzan.banished:
		return
	if context['target'] == muzan:
		return   # a self-heal (including this passive's own +5) is not "healing an ally"
	Character.resolve_effect_healing(context, context['effect'], muzan, 5)

func on_affected_acts(context):
	var actor = context['owner']
	var muzan = context['effect'].user
	if muzan.dead or muzan.banished:
		return
	for e in actor.effects.get_effects_by_type(EffectType.Type.DAMAGE):
		if e.user == muzan and e.damage_type == DamageType.Type.BLEED:
			e.duration += 2
	for e in actor.effects.get_effects_by_type(EffectType.Type.HEALING):
		if e.user == muzan:
			e.duration += 2

func extra_usable(user):
	return true

func custom_behavior(context):
	return [[0, [user, "PASS", []]]]

func target(user, battle):
	default_self_target_function(user, battle)
