extends Ability
var base_damage = 30
var base_aff = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 affliction damage to one enemy. If the target is marked by 'Blood Demon Art', they also are dealt an additional 5 affliction damage and then 5 the following 2 turns."

func split_desc():
	return [
		"Deals 30 Affliction damage to target enemy",
		["If marked by Blood Demon Art, deals 5 more Affliction damage now and 5 each turn for 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var marked = Condition.has_effect(target, "Blood Demon Art", EffectType.Type.MARK, user)
		var aff_boost = 0
		if marked.satisfied(context):
			aff_boost += base_aff
		Character.resolve_damage(context, target, base_damage + aff_boost, DamageType.Type.AFFLICTION)
		if aff_boost > 0:
			var damage_eff = Effect.damage_effect(base_aff, DamageType.Type.AFFLICTION, 5)
			damage_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, damage_eff)
		
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
