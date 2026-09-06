extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, if target enemy uses a Harmful skill, it will be countered, and Gogeta will deal 25 damage to the user, or to the user's team if the countered skill was AOE. For 2 turns after using this skill, all of Gogeta's Red costs turn to Random. This effect is invisible."

func split_desc():
	return [
		"Counters the next Harmful skill used by target enemy (Invisible)",
		"Deals 25 damage to countered enemies, or to all enemies if the countered skill was AOE",
		"Gogeta's skills cost Random instead of Red energy for 2 turns"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect("Bluff Kamehameha", EffectType.Type.COST_MOD):
		user.manually_advance_mission(10, 1)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new Harmful skill, they will be countered.", ["Harmful"])
		counter.invisible = true
		counter.wrapup_func = default_counter_timeout
		counter.set_source(self)
		Character.add_hostile_effect(context, user, target, counter)
	var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.RED, 5, [])
	color_change.set_source(self)
	color_change.invisible = true
	Character.add_allied_effect(context, user, user, color_change)

func counter_trigger(context):
	var skill = context['owner'].used_ability
	var countered = context['owner']
	context['owner'] = user
	if skill.target_type() == TargetType.Type.ALL:
		var targets = []
		for character in user.battle.all_characters():
			if user.is_hostile(character) and not character.is_invuln(self) and not character.dead:
				targets.append(character)
		for target in targets:
			Character.resolve_effect_damage(context, context['effect'], target, 25, DamageType.Type.NORMAL)
	else:
		Character.resolve_effect_damage(context, context['effect'], countered, 25, DamageType.Type.NORMAL)
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
