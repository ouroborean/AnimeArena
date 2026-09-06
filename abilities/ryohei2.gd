extends Ability
var base_healing = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Heals your entire team for 10. This skill lasts 1 additional turn and costs 1 additional random for every stack of To the Extreme!!, consuming all stacks on use."

func split_desc():
	return [
		["Heals your entire team for 10, +1 turn and +1 random cost per stack of To the Extreme!! (consumes all stacks)", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stacks = 0
	if user.has_effect("To the Extreme!!", EffectType.Type.EMPTY, user):
		stacks = user.has_effect("To the Extreme!!", EffectType.Type.EMPTY, user).stacks
	var duration = 1 + (stacks * 2)
	if user.marked_by("Vongola Headgear", user):
		user.manually_advance_mission(10, 1)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, base_healing)
		if user.marked_by("Vongola Headgear", user):
			var dr = Effect.damage_reduction_effect(10, duration - 1)
			dr.set_source(self)
			Character.add_allied_effect(context, user, target, dr)
		if user.marked_by("To the Extreme!!", user):
			var healing_eff = Effect.healing_effect(base_healing, duration)
			healing_eff.set_source(self)
			Character.add_allied_effect(context, user, target, healing_eff)
			var extreme = user.effects.get_all_effects_by_name("To the Extreme!!", user)
			for effect in extreme:
				if effect.effect_type == EffectType.Type.MARK:
					effect.stacks = 0
					continue
				if effect.effect_type == EffectType.Type.DAMAGE_RECEIVE_TRIGGER:
					continue
				user.effects.erase_effect(effect)
	

func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 15, 1.8)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
