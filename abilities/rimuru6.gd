extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Targets one enemy for one turn. If they use a new harmful skill, it will be countered then copied for 1 turn. The copied skill will have no cost. Invisible."

func split_desc():
	return [
		"For 1 turn, if target enemy uses a new Harmful skill, it is countered and copied for 1 turn",
		["The copied skill costs nothing", Color.CADET_BLUE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter = Effect.counter_effect(Trigger.always(beelz_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new harmful skill, it will be countered and copied for 1 turn.", ["Harmful"])
		counter.set_source(self)
		counter.wrapup_func = default_counter_timeout
		counter.invisible = true
		Character.add_hostile_effect(context, user, target, counter)
		
		
func beelz_trigger(context):
	var attacker = context['owner']
	var user = context['effect'].user
	var ability = attacker.used_ability
	user.manually_advance_mission(6, 1)
	var copy_effect = Effect.copy_effect(ability, 1, 2, user)
	copy_effect.set_source(self)
	var cost_change_effect = Effect.cost_change_effect({}, 2, [ability.ability_name])
	cost_change_effect.set_source(self)
	
	Character.add_allied_effect(context, user, user, copy_effect)
	Character.add_allied_effect(context, user, user, cost_change_effect)
	
	default_counter_trigger(context)
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 20)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.has_effect("Slime Transformation", EffectType.Type.IGNORE_NON_DAMAGE, user) == null
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
