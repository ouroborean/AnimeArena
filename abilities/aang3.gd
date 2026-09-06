extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The next skill one enemy uses will have its damage capped at 10. If Aang is Earth-Aligned, this will cap the damage of the next 2 skills the target uses instead. If used the turn after Fire Kick, this deals 10 affliction damage to the target every turn it is active."

func split_desc():
	return [
		"Target enemy's next skill cannot deal more than 10 damage.",
		"Affects next 2 skills if Earth-Aligned.",
		"Deals 10 Affliction damage per turn if Fire Kick used last turn."
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var earth_aligned = Condition.mag_is(user, "Avatar Cycle", EffectType.Type.MARK, user, 2, 2)
	var alignment_boost = 0
	if earth_aligned.satisfied(context):
		alignment_boost = 1
	var fire_touched = Condition.has_effect(user, "Fire Kick", EffectType.Type.MARK, user)
	for target in user.targeter.targets:
		var trigger_desc = func (eff):
			return "If this character uses a new skill, this effect will end."
		var trigger = Trigger.from_condition(Condition.always(), earth_trigger)
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
		trigger_eff.refresh = true
		trigger_eff.set_source(self)
		trigger_eff.cleansable = true
		
		var eff = Effect.damage_cap(10, -1)
		eff.set_source(self)
		eff.display_stacks = true
		eff.stackable = true
		eff.stacks = 1 + alignment_boost
		eff.set_source(self)
		
		
		Character.add_hostile_effect(context, user, target, trigger_eff)
		Character.add_hostile_effect(context, user, target, eff)
		
		if fire_touched.satisfied(context):
			
			var fire_eff = Effect.damage_effect(10, DamageType.Type.AFFLICTION, -1, true)
			fire_eff.set_source(self)
			Character.add_hostile_effect(context, user, target, fire_eff)
			Character.resolve_effect_damage(context, fire_eff, target, 10, DamageType.Type.AFFLICTION)
		
	if earth_aligned.satisfied(context):
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 3
	var earth_mark_desc = func (eff):
		return "Water Whip will be improved."
	var earth_mark = Effect.mark(3, earth_mark_desc)
	earth_mark.set_source(self)
	Character.add_allied_effect(context, user, user, earth_mark)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 35)
	
	return variations

func earth_trigger(context):
	var target = context['owner']
	if not target.has_effect("Earth Pillars", EffectType.Type.DAMAGE_CAP):
		return
	
	target.effects.has_effect("Earth Pillars", EffectType.Type.DAMAGE_CAP, user).consume_stack(1)
	
	var pillars_left = Condition.has_effect(target, "Earth Pillars", EffectType.Type.DAMAGE_CAP, user)
	if not pillars_left.satisfied(context):
		target.effects.full_remove_effect_by_name("Earth Pillars")


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
