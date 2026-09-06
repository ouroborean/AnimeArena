extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Whenever Marco receives damage, he instantly heals 5 HP per 15 damage received",
		["Marco deals 5 more damage the following turn whenever this effect activates", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "For each 15 damage Marco receives, he heals 5 HP and deals 5 more damage the following turn.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)

func damage_trigger(context):
	var increments = int(context.value / 15)
	var eff = context.effect
	if increments > 0:
		user.manually_advance_mission(8, 1)
		context = QueryContext.from_game_state(user, user.battle)
		Character.resolve_effect_healing(context, eff, user, 5 * increments)
		for i in range(increments):
			var boost = Effect.damage_mod_effect(5, 2)
			boost.set_source(self)
			boost.stackable = true
			boost.display_stacks = true
			boost.stack_mag = true
			Character.add_allied_effect(context, user, user, boost)
		
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
	default_allied_target_function(user, battle)
