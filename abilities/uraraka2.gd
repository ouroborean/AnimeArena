extends Ability

var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Every enemy marked by 'Zero Gravity' takes 20 damage and has the cost of their skills increased by 1 random energy until they use a new skill (stacks)."

func split_desc():
	return [
		"Deals 20 damage to target enemy and increases the cost of their skills by 1 Random energy (stacks)",
		["Deals 5 more damage per stack of Zero Gravity on the target", Color.CADET_BLUE],
		["This effect persists until they use a new skill", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var zg_stacks = 0
		var zg = target.has_effect("Zero Gravity", EffectType.Type.DAMAGE_MOD, user)
		if zg:
			zg_stacks = zg.stacks
		Character.resolve_damage(context, target, base_damage + 5 * zg_stacks, DamageType.Type.NORMAL)
		
		var cost_mod_eff = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM)
		cost_mod_eff.set_source(self)
		cost_mod_eff.stackable = true
		cost_mod_eff.per_stack = true
		var trigger = Trigger.from_condition(Condition.always(), gravity_trigger)
		var trigger_desc = func(eff):
			return "If this character uses a new skill, this effect will end."
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
		trigger_eff.set_source(self)
		trigger_eff.cleansable = true
		trigger_eff.refresh = true
		trigger_eff.stackable = true
		trigger_eff.display_stacks = true
		
		Character.add_hostile_effect(context, user, target, cost_mod_eff)
		Character.add_hostile_effect(context, user, target, trigger_eff)


func gravity_trigger(context):
	context['owner'].effects.full_remove_effect_by_name("Gravity Plus")


		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context)
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	default_hostile_target_function(user, battle)
		
