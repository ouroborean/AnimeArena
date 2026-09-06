extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, if target enemy uses a Harmful skill, it will replace this skill for 1 turn.",
		["If not triggered, swaps with a random Projection skill or another skill previously copied", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Effect.trigger_effect(Trigger.always(harmful_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 2, "If this character uses a Harmful skill, it will replace this skill for 1 turn.")
		trigger.set_source(self)
		trigger.wrapup_func = timeout_trigger
		Character.add_hostile_effect(context, user, target, trigger)

func timeout_trigger(context):
	var tracker = user.has_effect("Unlimited Blade Works", EffectType.Type.ACTION_USE_TRIGGER)
	var copied_skills = tracker.ability_targets
	var roll = user.battle.roll(2, 5 + len(copied_skills))
	var target_skill
	if roll <= 5:
		target_skill = user.moveset.abilities[roll]
	else:
		roll -= 6
		target_skill = copied_skills[roll]
	var copy = Effect.copy_effect(target_skill, user.moveset.get_active_abilities(user).find(self), 2, user)
	copy.unique_render_id = int(Time.get_ticks_msec())
	copy.set_source(self)
	Character.add_allied_effect(context, user, user, copy)

func harmful_trigger(context):
	var attacker = context['target']
	var copy_target = attacker.used_ability
	
	user.manually_advance_mission(8, 1)
	var copy = Effect.copy_effect(copy_target, user.moveset.get_active_abilities(user).find(self), 2, user)
	copy.set_source(self)
	var tracker = user.has_effect("Unlimited Blade Works", EffectType.Type.ACTION_USE_TRIGGER)
	tracker.ability_targets.append(copy_target)
	Character.add_allied_effect(context, user, user, copy)
	attacker.effects.remove_effect(context['effect'].source.ability_name, context['effect'].effect_type, context['effect'].user)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 40)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
