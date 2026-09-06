extends Ability

var base_damage = 10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 10 energy damage and 10 piercing damage to one enemy. For 1 turn, if this target uses a new non-strategic skill, they will take 10 affliction damage."

func split_desc():
	return [
		"Deals 10 damage and 10 Piercing damage to target enemy",
		["For 1 turn, deals 10 Affliction damage to that enemy if they use a non-Strategic skill", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
		var trigger_desc = func (eff):
			return "If this character uses a new non-Strategic skill, they will take 10 affliction damage."
		var trigger = Trigger.from_condition(Condition.always(), detonate_trigger)
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, 2, trigger_desc)
		trigger_eff.set_source(self)
		
		Character.add_allied_effect(context, user, target, trigger_eff)
		

func detonate_trigger(context):
	var target = context['target']
	var user = context['owner']
	if not target.used_ability:
		return
	if target.used_ability.classes["Strategic"]:
		return
	Character.resolve_effect_damage(context, context['effect'], target, 10, DamageType.Type.AFFLICTION)
	target.effects.remove_effect("Detonating Touch", EffectType.Type.ACTION_USE_TRIGGER, user)
	

func custom_behavior(context):
	var variations = []
	var bakugo = context['owner']
	var stacks = 0
	if bakugo.has_effect("Nitroglycerin Storage", EffectType.Type.DAMAGE_MOD, bakugo):
		stacks = bakugo.has_effect("Nitroglycerin Storage", EffectType.Type.DAMAGE_MOD, bakugo).stacks
	
	variations += behavior_single_target_damage(context, 50 + (10 * stacks), 0.8)
	
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
