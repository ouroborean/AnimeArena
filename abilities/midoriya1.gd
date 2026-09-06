extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to one enemy and stuns their helpful skills for 1 turn. The following turn, Midoriya will deal 10 additional damage to them."

func split_desc():
	return [
		"Deals 10 damage to target enemy",
		"Stuns their Helpful skills for 1 turn",
		["Next turn, Midoriya deals 10 more damage to them", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var stun_eff = Effect.stun_effect(2, ["Helpful"])
		stun_eff.set_source(self)
		var vuln_eff = Effect.vulnerability_effect(10, 3, ["Blackwhip", "St. Louis Smash", "Detroit Smash", "Faux 100%"])
		vuln_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, stun_eff)
		Character.add_hostile_effect(context, user, target, vuln_eff)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	var bypassing = false
	if context['owner'].has_effect("Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user):
		bypassing = true
	
	variations += behavior_single_target_stun(context, 75, bypassing)
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	var faux = Condition.has_effect(user, "Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user)
	var bypassing = false
	if faux.satisfied(context):
		bypassing = true
	
	default_hostile_target_function(user, battle, bypassing)
