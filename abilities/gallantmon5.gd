extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 True damage to target enemy. If this skill is replacing Gallant Guard, Gallantmon becomes Invulnerable for 1 turn. If this skill is replacing Lightning Joust, the enemy is also stunned for 1 turn."

func split_desc():
	return [
		"Deals 30 True damage to target enemy",
		"Gallantmont becomes Invulnerable for 1 turn if replacing Gallant Guard",
		"Stuns the target for 1 turn if replacing Lightning Joust"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var offensive = user.effects.has_effect("Lightning Joust", EffectType.Type.ABILITY_SWAP, user)
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		if offensive:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)
	
	if offensive == null:
		var invuln = Effect.invuln_effect(2)
		invuln.set_source(self)
		Character.add_allied_effect(context, user, user, invuln)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 95)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
