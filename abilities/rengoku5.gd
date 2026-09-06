extends Ability
var base_damage = 40
var base_bleed = 5
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 damage to the target and inflicts 5 Bleed damage for 2 turns. If the enemy is Shattered, this bleed effect lasts an additional turn. Uncounterable."

func split_desc():
	return [
		"Deals 40 damage to target enemy",
		"Inflicts 5 Bleed damage for 2 turns",
		["Bleed lasts an extra turn if the target is Shattered", Color.ORANGE_RED],
		["Uncounterable", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var bleed_duration = 5
		if len(target.effects.get_effects_by_type(EffectType.Type.DEF_NEGATE)) > 0:
			bleed_duration += 2
		var bleed_eff = Effect.damage_effect(base_bleed, DamageType.Type.BLEED, bleed_duration, false)
		bleed_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, bleed_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 110, 0.9)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
