extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy. This skill will stun if Gon has 'Jajanken Stance' active."

func split_desc():
	return [
		"Deals 30 damage to target enemy",
		"Stuns for 1 turn if Jajanken Stance is active"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var jajanken = Condition.has_effect(user, "Jajanken Stance", EffectType.Type.ACTION_USE_TRIGGER, user)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
		if jajanken.satisfied(context):
			var stun_eff = Effect.stun_effect(2)
			stun_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, stun_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_stun(context, 150)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
