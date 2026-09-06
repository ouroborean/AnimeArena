extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Zoro will counter the first enemy skill used on target ally for 1 turn. Invisible."

func split_desc():
	return [
		"For 1 turn, counters the first Harmful skill used on Zoro or target ally (Invisible)",
		["If triggered, Zoro activates Master of Swords", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var trigger = Trigger.always(sword_trigger)
		var counter_receive = Effect.counter_effect(trigger, EffectType.Type.COUNTER_RECEIVE, 2, "The first enemy skill used on this character will be countered.")
		counter_receive.invisible = true
		counter_receive.wrapup_func = default_counter_timeout
		counter_receive.set_source(self)
		Character.add_allied_effect(context, user, target, counter_receive)


func sword_trigger(context):
	var ign_eff = Effect.ignore_effect_effect(3, EffectType.Type.STUN)
	ign_eff.set_source(user.moveset.base_abilities[1])
	var buff_eff = Effect.damage_mod_effect(5, -1)
	buff_eff.set_source(user.moveset.base_abilities[1])
	buff_eff.stackable = true
	buff_eff.stack_mag = true
	buff_eff.display_stacks = true
	var portrait = Effect.portrait_change_effect(0, 3)
	portrait.set_source(user.moveset.base_abilities[1])
	Character.add_allied_effect(context, user, user, portrait)
	Character.add_allied_effect(context, user, user, ign_eff)
	Character.add_allied_effect(context, user, user, buff_eff)
	
	var swap = Effect.ability_swap_effect(4, 1, user, 3)
	swap.set_source(user.moveset.base_abilities[1])
	Character.add_allied_effect(context, user, user, swap)
	
	
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	for character in context['ally_team'].characters:
		if not (character.dead or character.banished) and not character == context['owner']:
			variations.append([100 + (100 - character.health.hp), [context['owner'], self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
