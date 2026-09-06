extends Ability

var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to one enemy. If Aang is Air-Aligned, this deals 5 additional damage and the next skill they use will be delayed for 1 turn. If used the turn after Water Whip, this will reduce all the target's damage by 20 for 1 turn."

func split_desc():
	return [
		"Deals 20 damage to target enemy.",
		"+5 damage and delays if Aang is Air-Aligned",
		"Target deals -20 damage for 1 turn if Water Whip used last turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var air_aligned = Condition.mag_is(user, "Avatar Cycle", EffectType.Type.MARK, user, 0, 0)
	var alignment_boost = 0
	if air_aligned.satisfied(context):
		
		alignment_boost = 5
	
	var water_touched = Condition.has_effect(user, "Water Whip", EffectType.Type.MARK, user)
	
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + alignment_boost, DamageType.Type.NORMAL)
		if air_aligned.satisfied(context):
			var delay_effect = Effect.delay_eff(1, 2, 1, ["Harmful"])
			delay_effect.set_source(self)
			Character.add_hostile_effect(context, user, target, delay_effect)
			
			
		
		if water_touched.satisfied(context):
			var weak_eff = Effect.damage_mod_effect(-20, 2)
			weak_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, weak_eff)
	
	if air_aligned.satisfied(context):
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 1
	
	var air_mark_desc = func (eff):
		return "Fire Kick will be improved."
	var air_mark = Effect.mark(3, air_mark_desc)
	air_mark.set_source(self)
	Character.add_allied_effect(context, user, user, air_mark)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
