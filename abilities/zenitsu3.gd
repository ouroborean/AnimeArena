extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Zenitsu deals 30 piercing damage to one enemy. If Zenitsu is under the effect of both Speed of Thunder and Thunder Release, he will instead deal 15 piercing damage twice."

func split_desc():
	return [
		"Deals 30 piercing damage to one enemy; if under both Speed of Thunder and Thunder Release, instead deals 15 piercing damage twice"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var thunder = Condition.has_effect(user, "Thunder Release", EffectType.Type.ACTION_USE_TRIGGER, user)
	var speed = Condition.has_effect(user, "Speed of Thunder", EffectType.Type.ACTION_USE_TRIGGER, user)
	var portrait = Effect.portrait_change_effect(0, 2)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	
	for target in user.targeter.targets:
		if thunder.satisfied(context) and speed.satisfied(context):
			Character.resolve_damage(context, target, base_damage / 2, DamageType.Type.PIERCING)
			Character.resolve_damage(context, target, base_damage / 2, DamageType.Type.PIERCING)
		else:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
