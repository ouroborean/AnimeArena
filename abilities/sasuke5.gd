extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, if target enemy uses a new Harmful skill, they will be countered, take 15 damage and be Stunned for 1 turn (Invisible)",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var counter_eff = Effect.counter_effect(Trigger.always(counter_trigger), EffectType.Type.COUNTER_USE, 2, "If this character uses a new Harmful skill, they will be countered, take 15 damage and be Stunned for 1 turn.", ["Harmful"])
		counter_eff.set_source(self)
		counter_eff.invisible = true
		counter_eff.wrapup_func = default_counter_timeout
		Character.add_hostile_effect(context, user, target, counter_eff)

func counter_trigger(context):
	var victim = context['owner']
	var sasuke = context['effect'].user
	Character.resolve_effect_damage(context, context['effect'], victim, 15, DamageType.Type.NORMAL)
	# Duration 3, not the usual 2. This stun is applied from a COUNTER, which fires during the
	# ENEMY's turn: a duration-2 stun would tick down at the end of that turn and again at the end of
	# Sasuke's, expiring before the countered enemy ever reached a turn they could have acted on. 3
	# carries it through their next turn, which is the one the stun is meant to take.
	var stun = Effect.stun_effect(3)
	stun.set_source(self)
	Character.add_hostile_effect(context, sasuke, victim, stun)
	default_counter_trigger(context)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_hostile(context, 75)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
