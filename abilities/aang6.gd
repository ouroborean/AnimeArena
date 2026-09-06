extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "When this state is activated, Aang removes all enemy skills from himself and ignores stuns for 4 turns. Each turn, he gains a specific color energy corresponding to each element. (White -> Blue -> Green -> Red)."

func split_desc():
	return [
		"Aang cleanses himself and ignores stuns for 4 turns",
		["Aang gains 1 energy each turn, in the following order: White -> Blue -> Green -> Red", Color.WHITE],
		"Aang can only trigger this skill by using Fire Kick while Fire-Aligned",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		#Put execution per target here
		pass
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func activate(context):
	context['owner'].effects.cleanse_all_enemy_effects(context['owner'])
	var stun_ignore = Effect.ignore_effect_effect(7, EffectType.Type.STUN)
	stun_ignore.set_source(self)
	var trigger_desc = func (eff):
		return "Aang will cycle into the next state in the Avatar Cycle and gain a matching energy."
	var trigger = Trigger.from_condition(Condition.always(), avatar_state_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.END_OF_TURN_TRIGGER, 9, trigger_desc)
	trigger_eff.mag = 0
	trigger_eff.set_source(self)
	
	Character.add_allied_effect(context, context['owner'], context['owner'], trigger_eff)
	Character.add_allied_effect(context, context['owner'], context['owner'], stun_ignore)
	
	
	

func avatar_state_trigger(context):
	var eff = context['effect']
	if eff.mag == 0:
		eff.user.gain_bonus_energy(Energy.Type.WHITE)
		eff.mag = 1
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, context['owner']).mag = 0
	elif eff.mag == 1:
		eff.user.gain_bonus_energy(Energy.Type.BLUE)
		eff.mag = 2
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 1
	elif eff.mag == 2:
		eff.user.gain_bonus_energy(Energy.Type.GREEN)
		eff.mag = 3
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 2
	elif eff.mag == 3:
		eff.user.gain_bonus_energy(Energy.Type.RED)
		user.effects.has_effect("Avatar Cycle", EffectType.Type.MARK, user).mag = 3
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	pass
