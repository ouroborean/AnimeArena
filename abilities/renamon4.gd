extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 10 damage to target enemy",
		["Renamon becomes Invulnerable to non-Strategic skills for 1 turn", Color.DIM_GRAY],
		["Permanently, Renamon becomes Invulnerable to Strategic skills for 1 turn when it uses a non-Strategic skill", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 10, DamageType.Type.NORMAL)
	var invuln = Effect.invuln_effect(2, [], ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)
	if not user.has_effect("High Speed Leap", EffectType.Type.ACTION_USE_TRIGGER):
		var trigger = Effect.trigger_effect(Trigger.always(renamon_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "Renamon will become Invulnerable to Strategic skills for 1 turn when it uses a non-Strategic skill")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, user, trigger)
	if user.has_effect("Korenkyaku", EffectType.Type.ACTION_USE_TRIGGER) and user.has_effect("Diamond Storm", EffectType.Type.ACTION_USE_TRIGGER):
		user.manually_advance_mission(9, 1)

func renamon_trigger(context):
	if context.source.classes["Strategic"]:
		return
	var invuln = Effect.invuln_effect(2, ["Strategic"])
	invuln.set_source(self)
	Character.add_allied_effect(context, user, user, invuln)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 15)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
