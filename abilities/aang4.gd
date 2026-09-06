extends Ability

var base_damage = 40

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 40 affliction damage to one enemy. If Aang is Fire-Aligned, this deals 15 additional damage. If used the turn after Air Sphere, the entire enemy team is also dealt 5 affliction damage for 2 turns, Bypassing Invulnerability."

func split_desc():
	return [
		"Deals 40 Affliction damage to target enemy",
		"+15 damage if Fire-Aligned",
		"Deals 5 Affliction damage to all enemies for 2 turns if Air Sphere used last turn (Bypasses)"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var fire_aligned = Condition.mag_is(user, "Avatar Cycle", EffectType.Type.MARK, user, 3, 3)
	var alignment_boost = 0
	if fire_aligned.satisfied(context):
		alignment_boost = 15
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 0
	
	var air_touched = Condition.has_effect(user, "Air Sphere", EffectType.Type.MARK, user)
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + alignment_boost, DamageType.Type.AFFLICTION)
		
	if air_touched.satisfied(context):
		for target in user.battle.all_characters():
			if user.is_hostile(target) and not (target.dead or target.banished):
				
				var fire_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 3)
				fire_eff.set_source(self)
				Character.add_hostile_effect(context, user, target, fire_eff)
				
				Character.resolve_effect_damage(context, fire_eff, target, 5, DamageType.Type.AFFLICTION)
	
	var fire_mark_desc = func (eff):
		return "Earth Pillars will be improved."
	var fire_mark = Effect.mark(3, fire_mark_desc)
	fire_mark.set_source(self)
	Character.add_allied_effect(context, user, user, fire_mark)

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
