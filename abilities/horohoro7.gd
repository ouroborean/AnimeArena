extends Ability

var base_damage = 40

func describe(user):
	return "Deals 40 damage to all currently stunned enemies. On the following turn, Horohoro deals 40 damage to all enemies that weren't initially damaged."

func split_desc():
	return [
		"Deals 40 damage to all currently stunned enemies",
		"Next turn, Horohoro deals 40 damage to all enemies that weren't initially damaged (Bypassing)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var miss_list = []
	for target in user.targeter.targets:
		if not target.effects.get_effects_by_type(EffectType.Type.STUN).is_empty():
			Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
			var mark = Effect.mark(3, "This character won't be damaged by All-Swallowing Avalanche.")
			mark.set_source(self)
			Character.add_allied_effect(context, user, target, mark)
		else:
			miss_list.append(target)

	var followup = Effect.trigger_effect(
		Trigger.always(avalanche_followup),
		EffectType.Type.TICKING_TRIGGER,
		3,
		"Next turn, Horohoro deals 40 damage to enemies that weren't initially damaged.")
	followup.set_source(self)
	followup.character_targets = miss_list
	Character.add_allied_effect(context, user, user, followup)

func avalanche_followup(context):
	var eff = context.effect
	var horohoro = eff.user
	for enemy in eff.character_targets:
		if enemy == null or enemy.dead or enemy.banished:
			continue
		if not horohoro.is_hostile(enemy):
			continue
		if enemy.marked_by("All-Swallowing Avalanche"):
			continue
		Character.resolve_effect_damage(context, eff, enemy, base_damage, DamageType.Type.NORMAL)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_hostile_aoe_damage(context, 55, 1.2)

func target(user, battle):
	default_hostile_target_function(user, battle, true)
