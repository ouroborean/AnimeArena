extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nobara counters the first Harmful skill used by target enemy. Countered enemies are executed if their HP is 30 or less. If the target is affected by Straw Doll Technique, this skill lasts for 2 turns and deals 20 damage instead of executing. Invisible until triggered."

func split_desc():
	return [
		"Counters the first Harmful skill used by target enemy",
		["Countered enemies are executed if their HP is 30 or less", Color.ORANGE_RED],
		["If the target is affected by Straw Doll Technique, lasts 2 turns and deals 20 damage instead of executing", Color.ORANGE_RED],
		["Invisible until triggered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		var duration = 2
		var desc = "If this character uses a new Harmful skill, they will be countered and executed if their HP is below 30."
		if target.marked_by("Straw Doll Technique"):
			duration = 4
			desc = "If this character uses a new Harmful skill, they will be countered and receive 20 damage."
		
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_USE, duration, desc, ["Harmful"])
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, counter_eff)


func counter_trigger(context):
	var victim = context['owner']
	var nobara = context['effect'].user
	if victim.marked_by("Straw Doll Technique"):
		Character.resolve_effect_damage(context, context['effect'], victim, 20, DamageType.Type.NORMAL)
	else:
		if victim.health.hp <= 30:
			victim.execute_attempt(30, nobara, self)
	
	default_counter_trigger(context)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
