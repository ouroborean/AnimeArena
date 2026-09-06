extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The enemy marked by 'Chain Jail' is targeted until Kurapika dies. If they use 3 new skills, they will be instantly killed. While active, every turn the target does not use a new skill, they will take 10 affliction damage and lose 1 energy. May not be used while active. Unremovable."

func split_desc():
	return [
		"Targets the enemy marked by Chain Jail until Kurapika dies",
		["If they use 3 new skills, they are instantly killed", Color.ORANGE_RED],
		["Each turn they do not use a new skill, they take 10 Affliction damage and lose 1 energy", Color.ORANGE_RED],
		["Cannot be used while active; unremovable", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var ticking_trigger = Effect.trigger_effect(Trigger.always(chain_wait_trigger), EffectType.Type.END_OF_TURN_TRIGGER, -1, "If this character does not use a new skill, they will take 10 affliction damage and lose 1 energy.")
		ticking_trigger.set_source(self)
		var chain_desc = func (eff):
			return "If this character uses " + str(eff.mag) + " more skills, they will die."
		var on_use_trigger = Effect.trigger_effect(Trigger.always(chain_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, chain_desc)
		on_use_trigger.mag = 3
		on_use_trigger.display_mag = true
		on_use_trigger.set_source(self)
		Character.add_hostile_effect(context, user, target, ticking_trigger)
		Character.add_hostile_effect(context, user, target, on_use_trigger)

func chain_trigger(context):
	context['owner'].has_effect("Judgement Chain", EffectType.Type.ACTION_USE_TRIGGER, context['effect'].user).mag -= 1
	if context['owner'].has_effect("Judgement Chain", EffectType.Type.ACTION_USE_TRIGGER, context['effect'].user).mag <= 0:
		context['owner'].instant_kill(context['effect'].user, self)

func chain_wait_trigger(context):
	var user = context['effect'].user
	var target = context['target']
	if target.acted:
		return
	Character.resolve_effect_damage(context, context['effect'], target, 10, DamageType.Type.AFFLICTION)
	target.lose_energy(user)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_hostile_single_require_mark(context, "Chain Jail", EffectType.Type.STUN, 95)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character.has_effect("Chain Jail", EffectType.Type.STUN, user):
			check_hostile_target(user, character, context)
