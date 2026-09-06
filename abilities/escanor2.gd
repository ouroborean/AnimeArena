extends Ability

# Cruel Sun. A 4-turn all-enemy Affliction DoT (kurotsuchi6 pattern: manual first instance + dur 9).
# While it is active, Escanor gains +1 Sunshine whenever he uses a Harmful skill (on top of the passive).

func describe(user):
	return "For 4 turns, all enemies take 5 Affliction damage per turn. While Cruel Sun is active, Escanor gains an extra stack of Sunshine whenever he uses a Harmful skill."

func split_desc():
	return [
		"For 4 turns, all enemies take 5 Affliction damage per turn",
		["While active, Escanor gains 1 extra stack of Sunshine whenever he uses a Harmful skill", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# 5 Affliction per turn for 4 turns — manual first instance, then the ticking DAMAGE effect (dur 9)
		Character.resolve_damage(context, target, 5, DamageType.Type.AFFLICTION)
		var dot = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 9)
		dot.set_source(self)
		Character.add_hostile_effect(context, user, target, dot, true)
	# While Cruel Sun is active, each Harmful skill Escanor uses grants +1 Sunshine (routes through the
	# passive's gain_stacks for heal + cap). waiting=true (the use-trigger default) suppresses Cruel Sun's
	# own cast via `ability == eff.source`, so only LATER Harmful skills grant a stack.
	var gain = Effect.trigger_effect(Trigger.always(cruel_sun_harmful), EffectType.Type.HARMFUL_USE_TRIGGER, 9, "Escanor gains 1 Sunshine whenever he uses a Harmful skill.")
	gain.set_source(self)
	Character.add_allied_effect(context, user, user, gain)

func cruel_sun_harmful(context):
	var holder = context['effect'].user
	if holder.dead or holder.banished:
		return
	holder.moveset.base_abilities[4].gain_stacks(1)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 80)   # bot value weight, matching kurotsuchi6 for the same AoE DoT (not gameplay damage)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
