extends Ability

func describe(user):
	return "For 4 turns, all enemies' Strategic skills cost 1 more Random energy, and any affected enemy that uses a new skill takes 10 Piercing damage."

func split_desc():
	return [
		["For 4 turns, all enemies' Strategic skills cost 1 more Random energy", Color.CADET_BLUE],
		["While active, an affected enemy that uses a new skill takes 10 Piercing damage", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# COST_MOD matches by ability NAME, so collect the target's Strategic skill names (adam1.gd idiom).
		var strat = []
		for abi in target.moveset.get_active_abilities(target):
			if abi != null and abi.classes["Strategic"]:
				strat.append(abi.ability_name)
		if not strat.is_empty():
			var cost_up = Effect.cost_mod_effect(1, 8, Energy.Type.RANDOM, strat)
			cost_up.set_source(self)
			Character.add_hostile_effect(context, user, target, cost_up)
		var trig = Effect.trigger_effect(Trigger.always(tornado_trigger), EffectType.Type.ACTION_USE_TRIGGER, 8, "If this character uses a new skill, they take 10 Piercing damage.")
		trig.set_source(self)
		Character.add_hostile_effect(context, user, target, trig)

# Fires when the branded enemy uses a skill: context['target'] is that enemy (bakugo1.gd idiom).
func tornado_trigger(context):
	var target = context['target']
	if not target.used_ability:
		return
	Character.resolve_effect_damage(context, context['effect'], target, 10, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_hostile_aoe_damage(context, 15, 1.0)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
