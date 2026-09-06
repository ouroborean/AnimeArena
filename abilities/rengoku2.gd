extends Ability
var base_damage = 15
var base_bleed = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 15 Piercing damage to the target and inflicts 5 Bleed damage for 2 turns. If the target is Shattered, increase the Bleed to 10 per turn."

func split_desc():
	return [
		"Deals 15 Piercing damage to target enemy",
		"Inflicts 5 Bleed damage for 2 turns",
		["Bleed increases to 10 per turn if the target is Shattered", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var mod_bleed = base_bleed
		if len(target.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)) > 0:
			mod_bleed = 10
		var damage_eff = Effect.damage_effect(mod_bleed, DamageType.Type.BLEED, 5, false)
		damage_eff.set_source(self)
		damage_eff.remove_on_death = false
		Character.add_hostile_effect(context, user, target, damage_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 60, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
