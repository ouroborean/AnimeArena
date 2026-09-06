extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Esdeath deals 15 Piercing damage to all enemies",
		["Damaged enemies deal 5 less damage to Esdeath until the end of her next turn (This effect cannot be ignored)", Color.CADET_BLUE],
		["Cannot be Countered or Reflected", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 15, DamageType.Type.PIERCING)
		var threshold = 5
		for effect in target.effects.get_effects_by_type(EffectType.Type.STUN):
			threshold += 5
		for effect in target.effects.get_effects_by_type(EffectType.Type.SILENCE):
			threshold += 5
		for effect in target.effects.get_effects_by_type(EffectType.Type.SILENCE):
			if effect.mag < 0:
				threshold += 5
		if target.marked_by("Empire's Strongest"):
			threshold += 5
		if target.marked_by("Weiss Schnabel"):
			threshold += 5
		
		var mark = Effect.mark(3, "This character will deal 5 less damage to Esdeath")
		mark.set_source(self)
		Character.add_hostile_effect(context, user, target, mark)
		target.execute_attempt(threshold, user, self)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 20)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
