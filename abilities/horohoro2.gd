extends Ability

var base_damage = 25

func describe(user):
	return "Deals 25 damage to target enemy. If that enemy is stunned, they take an additional 15 damage and any stuns on them end. If they aren't stunned, they are stunned until the end of Horohoro's next turn."

func split_desc():
	return [
		"Deals 25 damage to target enemy",
		"If the target is stunned, they take +15 damage and all stuns on them end",
		"If the target is not stunned, they are stunned until the end of Horohoro's next turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var stuns = target.effects.get_effects_by_type(EffectType.Type.STUN)
		var was_stunned = not stuns.is_empty()
		var damage = base_damage + (15 if was_stunned else 0)
		Character.resolve_damage(context, target, damage, DamageType.Type.NORMAL)
		if target.dead:
			continue
		if was_stunned:
			for stun in stuns:
				target.effects.erase_effect(stun)
		else:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 40, 1.1)

func target(user, battle):
	default_hostile_target_function(user, battle)
