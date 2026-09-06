extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, the first Harmful skill used on target ally or Tokito will be countered (Invisible)",
		["The countered enemy will be Blinded for 1 turn", Color.CADET_BLUE],
		["During this time, damage dealt to them is considered to be dealt by Tokito", Color.AQUA]
	]
	
func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "The first enemy to use a Harmful skill on this character will be countered and Blinded.", ["Harmful"])
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, counter_eff)
	

func counter_trigger(context):
	var muichiro = context['effect'].user
	var attacker = context['owner']
	
	var blind = Effect.blind_effect(3)
	blind.set_source(self)
	var mark = Effect.mark(2, "Damage dealt to this character is considered to be dealt by Muichiro.")
	mark.set_source(self)
	Character.add_hostile_effect(context, muichiro, attacker, blind)
	Character.add_hostile_effect(context, muichiro, attacker, mark)
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 40)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
