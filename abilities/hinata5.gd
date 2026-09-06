extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For the next 4 turns, Hinata will deal 10 damage to any enemy she damages (other than with this effect). During this time, Hinata can use this skill to deal 15 damage to an enemy twice."

func split_desc():
	return [
		["For 4 turns, Hinata deals 10 bonus damage to any enemy she damages (except via this effect)", Color.CADET_BLUE],
		["While active, can be used to deal 15 damage to an enemy twice", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	
	if user.marked_by("Gentle Step: Twin Lions Fist"):
		for target in user.targeter.targets:
			if target.has_effect("My Turn To Protect", EffectType.Type.TAUNT):
				user.manually_advance_mission(6, 1)
			Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
			Character.resolve_damage(context, target, 15, DamageType.Type.NORMAL)
	else:
		var trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_DEALT_TRIGGER, 7, "Hinata will deal 10 damage to any enemy she damages (other than with this effect).")
		trigger.set_source(self)
		var mark = Effect.mark(7, "Gentle Step: Twin Lions Fist can be used to deal 15 damage to an enemy twice.")
		mark.set_source(self)

		Character.add_allied_effect(context, user, user, trigger)
		Character.add_allied_effect(context, user, user, mark)




func damage_trigger(context):
	if context['source'] is Effect:
		if context['source'].source.ability_name == "Gentle Step: Twin Lions Fist":
			return
	
	Character.resolve_effect_damage(context, context['effect'], context['target'], 10, DamageType.Type.NORMAL)
	


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Gentle Step: Twin Lions Fist"):
		default_hostile_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
