extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For the next 4 turns, Rakko is Invulnerable to Strategic skills and any time an enemy uses a new Strategic skill, Rakko will deal 5 Bleed damage to them for 2 turns."

func split_desc():
	return [
		"For 4 turns: Rakko is Invulnerable to Strategic skills",
		["If an enemy uses a new Strategic skill, Rakko deals 5 Bleed damage to them for 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Class-targeted invuln. With class_targets=["Strategic"], Rakko is
	# invulnerable only to Strategic skills (per the engine's invuln check
	# at character_component.gd is_invuln); other classes hit normally.
	var invuln = Effect.invuln_effect(9, ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

	# Per-enemy counter trigger. We install a separate ACTION_USE_TRIGGER on
	# each living enemy; the callback filters to Strategic-class actions and
	# applies a fresh Bleed package to that enemy.
	for enemy in battle.all_characters():
		if not user.is_hostile(enemy):
			continue
		if enemy.dead or enemy.banished:
			continue
		var trigger_desc = func (eff):
			return "If this character uses a new Strategic skill, they take 5 Bleed damage immediately plus 5 more next turn."
		var trigger = Effect.trigger_effect(
			Trigger.always(counter_bleed_trigger),
			EffectType.Type.ACTION_USE_TRIGGER,
			9,
			trigger_desc
		)
		trigger.set_source(self)
		Character.add_hostile_effect(context, user, enemy, trigger, true)

func counter_bleed_trigger(context):
	var enemy = context['owner']
	if enemy == null or enemy.dead or enemy.banished:
		return
	if enemy.used_ability == null:
		return
	if not enemy.used_ability.classes["Strategic"]:
		return
	var trigger_eff = context['effect']
	var rakko = trigger_eff.user
	if rakko == null or rakko.dead or rakko.banished:
		return
	# Immediate first-tick BLEED (the new DOT below won't tick on the same
	# turn it was applied, per the engine's standard DOT convention).
	Character.resolve_effect_damage(context, trigger_eff, enemy, 5, DamageType.Type.BLEED)
	# Follow-up tick on the next turn (1 more 5-damage tick). damage_type is
	# already BLEED but we also set the bleed flag explicitly so Close-Range
	# Rifle's "OR" detection counts it regardless of which convention readers
	# look for.
	var dot = Effect.damage_effect(5, DamageType.Type.BLEED, 3)
	dot.set_source(self)
	dot.bleed = true
	Character.add_hostile_effect(context, rakko, enemy, dot, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_self_panic_button(context, 30)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
