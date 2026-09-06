extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Ichigo deals 30 piercing damage to one enemy. For 1 turn, Ichigo becomes invulnerable to Strategic skills. This skill will deal 5 additional damage for each time 'Zangetsu Slash' and 'Flash Step Impale' were used."

func split_desc():
	return [
		"Deals 30 piercing damage to target enemy",
		["+5 damage for each previous use of Zangetsu Slash and Flash Step Impale", Color.CADET_BLUE],
		["Ichigo becomes invulnerable to Strategic skills for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	
	var invuln = Effect.invuln_effect(2, ["Strategic"])
	invuln.set_source(self)
	
	var boost = Effect.damage_mod_effect(5, -1, ["Flash Step Impale"])
	boost.set_source(self)
	boost.stackable = true
	boost.per_stack = true
	boost.display_stacks = true
	Character.add_allied_effect(context, user, user, boost)
	Character.add_allied_effect(context, user, user, invuln)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
