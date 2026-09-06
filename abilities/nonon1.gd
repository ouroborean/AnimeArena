extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Nonon deals 10 Piercing damage to one enemy and increases all non-Affliction damage they take by 5 for two turns."

func split_desc():
	return [
		"Deals 10 Piercing damage to target enemy",
		["They take 5 more non-Affliction damage for 2 turns", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		
		if target.has_effect("Overture Barrage", EffectType.Type.DAMAGE, user) or target.has_effect("Unstoppable Performance", EffectType.Type.DAMAGE, user):
			user.manually_advance_mission(7, 1)
		
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var vuln = Effect.vulnerability_effect(5, 4, [], [], [DamageType.Type.AFFLICTION])
		vuln.set_source(self)
		Character.add_hostile_effect(context, user, target, vuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
