extends Ability

# Landmines. Plants an invisible reactive trap on an ally (or Minene): when an enemy hits that ally with
# a Harmful skill, the attacker takes 10 Affliction and gains an Explosives Detonator charge. Then
# temporarily becomes Explosives Detonator (hidden base_abilities[5]) for 1 turn.

const DETONATOR = "Explosives Detonator"

func passive():
	return user.moveset.base_abilities[4]

func describe(user):
	return "Plants landmines on an ally or Minene for 1 turn. While active, any enemy that hits that ally with a Harmful skill takes 10 Affliction damage and gains a stack of Explosives Detonator. Landmines is replaced by Explosives Detonator for 1 turn."

func split_desc():
	return [
		["Plants landmines on an ally or Minene for 1 turn", Color.CADET_BLUE],
		["An enemy that hits the protected ally with a Harmful skill takes 10 Affliction damage and gains a stack of Explosives Detonator", Color.ORANGE_RED],
		["Landmines becomes Explosives Detonator for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trap = Effect.trigger_effect(Trigger.always(landmine_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "When an enemy hits this character with a Harmful skill, the attacker takes 10 Affliction damage and gains an Explosives Detonator charge.")
		trap.set_source(self)
		trap.invisible = true
		Character.add_allied_effect(context, user, target, trap)
	var swap = Effect.ability_swap_effect(5, 1, user, 3)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func landmine_trigger(context):
	if not context['source'].classes['Harmful']:
		return
	var attacker = context['owner']
	if attacker == null or attacker.dead or attacker.banished:
		return
	Character.resolve_effect_damage(context, context['effect'], attacker, 10, DamageType.Type.AFFLICTION)
	passive().grant_detonator_stack(attacker, 1)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_helpful(context, 0)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
