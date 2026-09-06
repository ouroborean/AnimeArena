extends Ability

var base_damage_reduction = -10

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Grants all enemies a stack of 'Zero Gravity'. Swaps to 'Gravity Plus' for 2 turns."

func split_desc():
	return [
		"All enemies receive a stack of Zero Gravity",
		["Enemies already affected by Zero Gravity also have Gravity Plus applied to them", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var gravity_plus_ability = user.moveset.base_abilities[1]
	for target in user.targeter.targets:
		if target.has_effect("Zero Gravity", EffectType.Type.DAMAGE_MOD, user):
			var gp_cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM)
			gp_cost_mod.set_source(gravity_plus_ability)
			gp_cost_mod.stackable = true
			gp_cost_mod.per_stack = true
			var gp_trigger = Trigger.from_condition(Condition.always(), gravity_plus_ability.gravity_trigger)
			var gp_trigger_desc = func(eff):
				return "If this character uses a new skill, this effect will end."
			var gp_trigger_eff = Effect.trigger_effect(gp_trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, gp_trigger_desc)
			gp_trigger_eff.set_source(gravity_plus_ability)
			gp_trigger_eff.cleansable = true
			gp_trigger_eff.refresh = true
			gp_trigger_eff.stackable = true
			gp_trigger_eff.display_stacks = true
			Character.add_hostile_effect(context, user, target, gp_cost_mod)
			Character.add_hostile_effect(context, user, target, gp_trigger_eff)

		var damage_mod_eff = Effect.damage_mod_effect(base_damage_reduction, -1)
		damage_mod_eff.set_source(user.moveset.base_abilities[0])
		damage_mod_eff.invisible = true
		damage_mod_eff.display_stacks = true
		damage_mod_eff.stackable = true
		damage_mod_eff.per_stack = true
		var trigger = Trigger.from_condition(Condition.always(), gravity_trigger)
		var trigger_desc = func(eff):
			return "If this character uses a new skill, they will lose 1 energy and this effect will end."
		var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
		trigger_eff.stackable = true
		trigger_eff.set_source(user.moveset.base_abilities[0])
		trigger_eff.cleansable = true
		trigger_eff.invisible = true

		Character.add_hostile_effect(context, user, target, damage_mod_eff)
		Character.add_hostile_effect(context, user, target, trigger_eff)


func gravity_trigger(context):
	context['owner'].lose_energy(context['effect'].user)
	context['effect'].user.manually_advance_mission(7, 1)
	context['owner'].effects.full_remove_effect_by_name("Zero Gravity")

	var notification_effect = Effect.invisible_expiration_effect(self)
	notification_effect.set_duration(2)
	notification_effect.set_source(context['effect'].user.moveset.base_abilities[1])
	Character.add_hostile_effect(context, context['effect'].user, context['owner'], notification_effect)


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var targets = []
	for character in context['enemy_team'].characters:
		if not character.is_invuln(self) and not (character.dead or character.banished):
			targets.append(character)
	if len(targets) == 0:
		variations.append([0, [user, "PASS", []]])
	else:
		variations.append([250, [user, self, targets]])
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
