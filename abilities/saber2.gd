extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Saber deals 20 damage to one enemy and ignores stun effects for one turn. If used while costing Green energy, for 1 turn this skill will cost 1 Random energy. If used while costing random energy, for 1 turn this skill will cost nothing. This skill cannot be countered."

func split_desc():
	return [
		"Saber deals 20 damage to one enemy",
		["Saber ignores stun effects for 1 turn", Color.CADET_BLUE],
		["If costing Green energy, for 1 turn this skill costs 1 Random energy", Color.CADET_BLUE],
		["If costing Random energy, for 1 turn this skill costs nothing", Color.CADET_BLUE],
		["Cannot be countered", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
	if cost()[Energy.Type.GREEN] >= 1:
		var cost_change = Effect.cost_change_effect({Energy.Type.RANDOM: 1}, 3, ["Wind Blade Combat", "Providence"])
		cost_change.set_source(self)
		Character.add_allied_effect(context, user, user, cost_change)
	elif cost()[Energy.Type.RANDOM] >= 1:
		var cost_change = Effect.cost_change_effect({}, 3, ["Wind Blade Combat", "Providence"])
		cost_change.set_source(self)
		Character.add_allied_effect(context, user, user, cost_change)
	var stun_ign = Effect.ignore_effect_effect(3, EffectType.Type.STUN)
	stun_ign.set_source(self)
	Character.add_allied_effect(context, user, user, stun_ign)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	
	variations += behavior_single_target_damage(context, 50, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
