extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 15 Bleed damage to target enemy for 3 turns, decreasing by 5 each turn."

func split_desc():
	return [
		"Deals 15 Bleed damage to target enemy",
		"Deals 10 Bleed damage next turn, then 5 the turn after"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		# Immediate first hit (unchanged).
		Character.resolve_damage(context, target, 15, DamageType.Type.BLEED)
		# The follow-up is now a NORMAL Bleed DoT (a DAMAGE-type effect) rather than a bespoke
		# TICKING_TRIGGER, so Bleed-detecting skills (Inosuke's Beast Breathing, Kaneki's Disembowel,
		# rakko2's count-Bleeds, staunch_bleeding, etc.) recognise it the same as any other Bleed.
		# It starts at 10 and is de-ramped by the accompanying ticking trigger below (10 -> 5 -> gone).
		var bleed = Effect.damage_effect(10, DamageType.Type.BLEED, 5)
		bleed.set_source(self)
		Character.add_hostile_effect(context, user, target, bleed)
		# Accompanying ticking trigger that MODIFIES the Bleed instead of dealing the damage itself:
		# it lowers the DoT's magnitude by 5 each turn. DAMAGE effects are processed before
		# TICKING_TRIGGERs, so the Bleed lands its current value first, then this reduces it for the
		# following turn -> 10, then 5, then it is removed.
		var deramp_desc = func (eff):
			return "Bleeding Shot: the Bleed damage decreases by 5 each turn."
		var deramp = Effect.trigger_effect(
			Trigger.always(deramp_tick),
			EffectType.Type.TICKING_TRIGGER,
			5,
			deramp_desc
		)
		deramp.set_source(self)
		Character.add_hostile_effect(context, user, target, deramp)

func deramp_tick(context):
	# Lower the accompanying Bleeding Shot DoT by 5; remove it once it would deal nothing.
	var target = context['target']
	var bleed = target.effects.has_effect("Bleeding Shot", EffectType.Type.DAMAGE, context['effect'].user)
	if bleed == null:
		return
	bleed.mag -= 5
	if bleed.mag <= 0:
		target.effects.erase_effect(bleed)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 35)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
