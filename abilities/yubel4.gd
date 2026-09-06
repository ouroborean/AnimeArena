extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "For 1 turn, if target enemy uses a new skill, they will be Taunted for 1 turn (Invisible)."

func split_desc():
	return [
		"For 1 turn, if target enemy uses a new skill, Taunts them for 1 turn (Invisible)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger_desc = func (eff):
			return "If this character uses a new skill, they will be Taunted for 1 turn."
		var trigger = Effect.trigger_effect(
			Trigger.always(malicious_intent_trigger),
			EffectType.Type.ACTION_USE_TRIGGER,
			2,
			trigger_desc
		)
		trigger.set_source(self)
		trigger.invisible = true
		# bypassing=true: this skill bypasses invuln to target (see target()), so the taunt-on-use watcher
		# must install on an invuln target too — otherwise it drops and the skill does nothing to them.
		Character.add_hostile_effect(context, user, target, trigger, true)

func malicious_intent_trigger(context):
	var enemy = context['owner']
	var taunt = Effect.taunt_effect(3, user)
	taunt.set_source(self)
	taunt.invisible = true
	Character.add_hostile_effect(context, user, enemy, taunt, true)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 30, true)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle, true)
