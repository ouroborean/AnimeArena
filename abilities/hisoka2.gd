extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Deals 15 damage to target enemy and Taunts them for 1 turn",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	for target in user.targeter.targets:
		# Deal 15 Normal Damage
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
		# Apply Taunt
		# Duration 3 is standard for "1 turn" control effects in this codebase 
		# (Covers current turn remainder + Enemy turn + Start of next)
		var taunt_eff = Effect.taunt_effect(2, user)
		taunt_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, taunt_eff)

func extra_usable(user):
	return true
	
func custom_behavior(context):
	# AI Behavior: Standard single target damage with moderate priority (75)
	# You might want to increase priority if the user is a tank, but Hisoka is likely a damage dealer.
	var variations = []
	variations += behavior_single_target_hostile(context, 75)
	return variations
	
func target(user, battle):
	default_hostile_target_function(user, battle)
