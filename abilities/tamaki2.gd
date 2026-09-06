extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tamaki targets one enemy for three turns. During this time, if they use a new harmful skill they will receive 5 affliction damage per turn for the rest of the game."

func split_desc():
	return [
		["Targets one enemy for 3 turns; if they use a new harmful skill, they receive 5 affliction damage per turn for the rest of the game", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var mark_eff = Effect.mark(5, "Nekomata Blaze and Nekomata Fireball will bypass invulnerability against this target.")
		mark_eff.set_source(self)
		var trigger_eff = Effect.trigger_effect(Trigger.always(cage_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 6, "If this character uses a new harmful skill, they will receive 5 Affliction damage per turn for the rest of the game.")
		trigger_eff.set_source(self)
		Character.add_hostile_effect(context, user, target, trigger_eff)
		Character.add_hostile_effect(context, user, target, mark_eff)

func cage_trigger(context):
	var caged = context['target']
	var damage_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1)
	damage_eff.set_source(self)
	damage_eff.stackable = true
	damage_eff.per_stack = true
	damage_eff.display_stacks = true
	damage_eff.unique_render_id = 1
	Character.add_hostile_effect(context, context['owner'], caged, damage_eff)

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	if target_type() == TargetType.Type.ALL:
		variations += behavior_hostile_aoe_damage(context, 75)
	else:
		variations += behavior_single_target_damage(context, 75)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
