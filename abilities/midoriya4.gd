extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.
func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Midoriya gains 5 points of damage reduction, increases his damage by 5, and ignores enemy stun effects for the rest of the game. This skill stacks. Midoriya loses 5HP every time he uses a new skill (stacks)."

func split_desc():
	return [
		["For the rest of the game, Midoriya gains 5 Damage Reduction and +5 damage (stacks)", Color.CADET_BLUE],
		["Midoriya loses 5 HP each time he uses a new skill (stacks)", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(5, -1)
	dr.stackable = true
	dr.per_stack = true
	dr.set_source(self)
	var damage_mod = Effect.damage_mod_effect(5, -1)
	damage_mod.stackable = true
	damage_mod.per_stack = true
	damage_mod.display_stacks = true
	damage_mod.set_source(self)
	var trigger_eff = Effect.trigger_effect(Trigger.always(full_cowl_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "If Midoriya uses a new skill, he will lose 5 health.")
	trigger_eff.set_source(self)
	trigger_eff.stackable = true
	
	Character.add_allied_effect(context, user, user, dr)
	Character.add_allied_effect(context, user, user, damage_mod)
	Character.add_allied_effect(context, user, user, trigger_eff)
	

func full_cowl_trigger(context):
	
	context['owner'].receive_damage(context['effect'].stack_count() * 5, context['owner'], self)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var mod = 0
	if not context['owner'].has_effect("One For All", EffectType.Type.DAMAGE_MOD, context['owner']):
		mod -= 75
	variations.append([200 + mod, [context['owner'], self, [context['owner']]]])
	
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
