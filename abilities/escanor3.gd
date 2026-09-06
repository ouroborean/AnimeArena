extends Ability

# Pride Flare. Affliction damage scaled +5 per FULL 2 Sunshine + a 1-turn Taunt, plus a self watcher
# scoped to the taunted enemy: if THAT enemy uses a new Harmful skill on Escanor on their next turn,
# he gains 1 Sunshine (the Taunt tends to force exactly that).

func describe(user):
	return "Deals 10 Affliction damage to target enemy and Taunts them for 1 turn. If that enemy uses a new Harmful skill on Escanor next turn, he gains 1 stack of Sunshine. Deals 5 more damage for each 2 stacks of Sunshine on Escanor."

func split_desc():
	return [
		"Deals 10 Affliction damage to target enemy and Taunts them for 1 turn",
		["Deals 5 more damage for each 2 stacks of Sunshine on Escanor", Color.CADET_BLUE],
		["If that enemy uses a new Harmful skill on Escanor next turn, he gains 1 Sunshine", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks = sunshine_stacks(user)
	var dmg = 10 + 5 * int(stacks / 2)   # +5 per FULL 2 stacks (int division floors)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.AFFLICTION)
		var taunt = Effect.taunt_effect(2, user)
		taunt.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt)
		# watcher on Escanor, scoped to THIS enemy for their next turn
		var watcher = Effect.trigger_effect(Trigger.always(punish_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "If the taunted enemy uses a new Harmful skill on Escanor, he gains 1 Sunshine.")
		watcher.set_source(self)
		watcher.invisible = true
		watcher.storage["watched"] = target
		Character.add_allied_effect(context, user, user, watcher)

func punish_trigger(context):
	var caster = context['effect'].user
	if caster == null or caster.dead or caster.banished:
		return
	if context['owner'] != context['effect'].storage.get("watched"):
		return   # only the taunted enemy counts
	caster.moveset.base_abilities[4].gain_stacks(1)
	caster.effects.consume_effect(context['effect'])   # fire once, then expire

func sunshine_stacks(u):
	var e = u.has_effect("Sunshine", EffectType.Type.MARK, u)
	return e.stack_count() if e else 0

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 10)

func target(user, battle):
	default_hostile_target_function(user, battle)
