extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 4 turns, Hinata's team gains 5 Damage Reduction. During this time, Hinata will deal 5 Piercing damage to any enemy that uses a new Harmful skill on her team, and this skill can be used for no cost to give an ally 10 Shield."

func split_desc():
	return [
		["For 4 turns, Hinata's team gains 5 Damage Reduction", Color.CADET_BLUE],
		["Hinata deals 5 Piercing damage to any enemy that uses a new Harmful skill on her team", Color.ORANGE_RED],
		["While active, can be used for free to give an ally 10 Shield", Color.CADET_BLUE],
		["Eight Trigrams: Air Palm costs 1 less Random while active", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if user.marked_by("Protective Eight Trigrams: 64 Palms"):
		for target in user.targeter.targets:
			var shield = Effect.shield_effect(10, -1)
			shield.set_source(self)
			shield.stackable = true
			shield.display_mag = true
			shield.stack_mag = true
			Character.add_allied_effect(context, user, target, shield)
	else:
		for target in user.targeter.targets:
			var trigger = Effect.trigger_effect(Trigger.always(on_receive_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 8, "Hinata will deal 5 Piercing damage to any enemy that uses a new Harmful skill on this character.")
			trigger.set_source(self)
			Character.add_allied_effect(context, user, target, trigger)
			var dr = Effect.damage_reduction_effect(5, 8)
			dr.set_source(self)
			Character.add_allied_effect(context, user, target, dr)
		var mark = Effect.mark(7, "Hinata is using Protective Eight Trigrams: 64 Palms. If she is stunned, it will be paused.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
		var cost_change = Effect.cost_change_effect({}, 7, ["Protective Eight Trigrams: 64 Palms"])
		cost_change.system = true
		cost_change.set_source(self)
		Character.add_allied_effect(context, user, user, cost_change)
		var target_change = Effect.target_change_effect(TargetType.Type.SINGLE, 7, ["Protective Eight Trigrams: 64 Palms"])
		target_change.system = true
		target_change.set_source(self)
		Character.add_allied_effect(context, user, user, target_change)
		var cost_mod = Effect.cost_mod_effect(-1, 7, 4, ["Eight Trigrams: Air Palm"])
		cost_mod.set_source(self)
		cost_mod.unique_render_id = 4
		Character.add_allied_effect(context, user, user, cost_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if user.marked_by("Protective Eight Trigrams: 64 Palms"):
		variations += behavior_single_target_helpful(context, 15)
	else:
		variations += behavior_helpful_aoe_aid(context, 50)
	
	return variations

func on_receive_trigger(context):
	if user.is_stunned(self):
		return
	if not context['source'].classes['Harmful']:
		return
	var thorn_target = context['owner']
	context['owner'] = user
	Character.resolve_effect_damage(context, context['effect'], thorn_target, 5, DamageType.Type.PIERCING)
	

func target(user, battle):
	default_allied_target_function(user, battle)
