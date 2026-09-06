extends Ability
var base_damage = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 Piercing damage to target enemy and marks them for 3 turns. Myotismon heals for any damage dealt by this skill."

func split_desc():
	return [
		"For 3 turns, target enemy is marked and takes 10 Piercing damage each turn",
		["Myotismon heals for any damage dealt by this skill", Color.CADET_BLUE]
	]

func execute(user, battle):
	health_drain = true
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var damage_eff = Effect.damage_effect(base_damage, DamageType.Type.PIERCING, 5)
		damage_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_eff)
		var mark = Effect.mark(7, "Disintegrate and Crimson Lightning are enhanced against this character.")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 60)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
