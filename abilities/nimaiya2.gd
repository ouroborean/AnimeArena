extends Ability
var base_damage = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 5 True damage to target enemy for 4 turns. During this time, that enemy takes 5 more damage from Unblockable Strike and Oetsu is invulnerable to Strategic skills. Bypasses."

func split_desc():
	return [
		"Deals 5 True damage to target enemy each turn for 4 turns, Bypassing Invulnerability",
		["The enemy takes 5 more damage from Unblockable Strike during this time", Color.ORANGE_RED],
		["Oetsu is invulnerable to Strategic skills during this time", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.TRUE)
		var multi_turn = Effect.damage_effect(base_damage, DamageType.Type.TRUE, 7)
		multi_turn.set_source(self)
		
		var damage_amp_eff = Effect.vulnerability_effect(5, 7, ["Unblockable Strike"])
		damage_amp_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_amp_eff, true)
		Character.add_hostile_effect(context, user, target, multi_turn, true)
	
	var invuln_eff = Effect.invuln_effect(6, ["Strategic"], [])
	invuln_eff.set_source(self)
	Character.add_allied_effect(context, user, user, invuln_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 50, 1.0, true)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle, true)
