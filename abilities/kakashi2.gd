extends Ability

var base_damage = 30

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 30 piercing damage to one enemy and removes 1 random energy from them. Until they use a new skill, the next skill the target uses will deal 100% less damage (invisible)."

func split_desc():
	return [
		"Deals 30 piercing damage to target enemy",
		"Removes 1 random energy from them",
		["Their next skill deals 100% less damage until they use a new skill", Color.ORANGE_RED],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mod_damage = get_true_damage(user, target, base_damage)
		if not target.is_ignoring_damage(true):
			context.battle.log_damage(user, target, mod_damage, DamageType.Type.PIERCING, user.used_ability)
			user.deal_ability_damage(user.used_ability, mod_damage, target, DamageType.Type.PIERCING)
		else:
			context.battle.log_invuln_block(user, target, user.used_ability)
		
		var trigger_desc = func (eff):
			return "If this character uses a new skill, this effect will end."
		var trigger = Trigger.from_condition(Condition.always(), kamui_trigger)
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
		trigger_eff.invisible = true
		trigger_eff.set_source(self)
		trigger_eff.cleansable = true
		
		var eff = Effect.damage_null_effect(1.0, -1)
		eff.invisible = true
		eff.set_source(self)
		
		Character.add_hostile_effect(context, user, target, trigger_eff)
		Character.add_hostile_effect(context, user, target, eff)
		target.lose_energy(user, 1)

func kamui_trigger(context):
	context['owner'].effects.full_remove_effect_by_name("Long-Range Kamui")
	var notification_effect = Effect.invisible_expiration_effect(self)
	notification_effect.set_source(self)
	Character.add_hostile_effect(context, context['effect'].user, context['owner'], notification_effect)
	
	
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
