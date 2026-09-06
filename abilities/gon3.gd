extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Damage to the enemy team. This skill will instead cost 1 Random, become piercing, and Blind its targets if 'Jajanken Stance' is active."

func split_desc():
	return [
		"Deals 10 damage to all enemies",
		"Becomes Piercing, costs 1 Random, and Blinds for 1 turn if Jajanken Stance is active"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var jajanken = Condition.has_effect(user, "Jajanken Stance", EffectType.Type.ACTION_USE_TRIGGER, user)
	
	for target in user.targeter.targets:
		var damage_type = DamageType.Type.NORMAL
		if jajanken.satisfied(context):
			damage_type = DamageType.Type.PIERCING
		Character.resolve_damage(context, target, base_damage, damage_type)
		
		if jajanken.satisfied(context):
			var blind_eff = Effect.blind_effect(2)
			blind_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, blind_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 35, 1.3)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
