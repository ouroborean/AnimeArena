extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 25 damage to one enemy. This skill deals 15 additional damage and costs 1 additional random for every stack of To the Extreme!!, consuming all stacks on use."

func split_desc():
	return [
		"Deals 25 damage to one enemy, +15 damage and +1 random cost per stack of To the Extreme!! (consumes all stacks)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var damage_type = DamageType.Type.NORMAL
	if user.marked_by("Vongola Headgear", user):
		damage_type = DamageType.Type.PIERCING
		user.manually_advance_mission(10, 1)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, damage_type)
		
	var extreme = user.effects.get_all_effects_by_name("To the Extreme!!", user)
	for effect in extreme:
		if effect.effect_type == EffectType.Type.MARK:
			effect.stacks = 0
			continue
		if effect.effect_type == EffectType.Type.DAMAGE_RECEIVE_TRIGGER:
			continue
		user.effects.erase_effect(effect)
		
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
