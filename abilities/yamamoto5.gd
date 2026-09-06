extends Ability
var base_damage = 30
var per_weakness = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 damage to one enemy, increased by 5 for each damage reducing effect on them."

func split_desc():
	return [
		"Deals 30 damage to one enemy, +5 per damage-reducing effect on them"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var weakness_effects = []
		var damage_mods = target.effects.get_effects_by_type(EffectType.Type.DAMAGE_MOD)
		for mod in damage_mods:
			if not mod.user in target.team.characters and mod.mag < 0:
				weakness_effects.append(mod)
		var mod_damage = base_damage + (per_weakness * len(weakness_effects))
		Character.resolve_damage(context, target, mod_damage, DamageType.Type.NORMAL)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 25)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
