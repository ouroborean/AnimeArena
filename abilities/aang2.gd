extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 damage to the enemy team and reduces their affliction damage by 10 for 2 turns. If Aang is Water-Aligned, this deals 5 additional damage and reduces all damage instead. If used the turn after Earth Pillars, this will stun their Physical, Affliction, and Strategic skills the first turn it deals damage."

func split_desc():
	return [
		"Deals 10 damage to all enemies for 2 turns. Targets deal -10 Affliction damage",
		"Affects all damage types and +5 damage if Water-Aligned.",
		"Stuns Physical/Affliction/Strategic skills on first turn if Earth Pillars used last turn."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var water_aligned = Condition.mag_is(user, "Avatar Cycle", EffectType.Type.MARK, user, 1, 1)
	var alignment_boost = 0
	if water_aligned.satisfied(context):
		
		alignment_boost = 5
	
	var earth_touched = Condition.has_effect(user, "Earth Pillars", EffectType.Type.MARK, user)
	
	
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + alignment_boost, DamageType.Type.NORMAL)
		var damage_effect = Effect.damage_effect(10, DamageType.Type.NORMAL, 3)
		damage_effect.set_source(self)
		Character.add_hostile_effect(context, user, target, damage_effect)
		var weakness_eff = Effect.damage_mod_effect(-10, 4, [], [DamageType.Type.AFFLICTION])
		if water_aligned.satisfied(context):
			weakness_eff = Effect.damage_mod_effect(-10, 4)
		weakness_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, weakness_eff)
		
		if earth_touched.satisfied(context):
			var stun_eff = Effect.stun_effect(2, ["Physical", "Affliction", "Strategic"])
			stun_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, stun_eff)
		
	if water_aligned.satisfied(context):
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 2
		
	var water_mark_desc = func (eff):
		return "Air Sphere will be improved."
	var water_mark = Effect.mark(3, water_mark_desc)
	water_mark.set_source(self)
	Character.add_allied_effect(context, user, user, water_mark)
		
func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_aoe_damage(context, 25)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
