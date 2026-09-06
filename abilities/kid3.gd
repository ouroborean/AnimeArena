extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 4 turns, any enemy that does not use a skill will take 10 damage and any ally that uses a skill heals 10 HP",
		["Swaps to Death Cannon while active", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		if target in user.team.characters:
			var trigger = Effect.trigger_effect(Trigger.always(ally_trigger), EffectType.Type.ACTION_USE_TRIGGER, 7, "If this character uses a new skill, they will heal 10 HP.")
			trigger.set_source(self)
			Character.add_allied_effect(context, user, target, trigger)
		else:
			var ticking = Effect.trigger_effect(Trigger.always(enemy_tick), EffectType.Type.END_OF_TURN_TRIGGER, 8, "If this character does not use a skill, they will take 10 damage.")
			ticking.set_source(self)
			Character.add_hostile_effect(context, user, target, ticking)
	var swap = Effect.ability_swap_effect(5, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func enemy_tick(context):
	if context['target'].acted:
		return
	Character.resolve_effect_damage(context, context.effect, context.target, 10, DamageType.Type.NORMAL)

	var boost = Effect.damage_mod_effect(5, -1, ["Death Cannon"])
	boost.set_source(self)
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	Character.add_allied_effect(context, user, user, boost)
	user.manually_advance_mission(7, 1)

func ally_trigger(context):
	Character.resolve_effect_healing(context, context.effect, context.owner, 10)
	var boost = Effect.damage_mod_effect(5, -1, ["Death Cannon"])
	boost.set_source(self)
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	Character.add_allied_effect(context, user, user, boost)
	user.manually_advance_mission(7, 1)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_all_target(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
