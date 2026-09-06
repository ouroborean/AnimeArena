extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Nagisa ignores all Harmful effects and damage. Any enemy that uses a Harmful skill is Silenced for 2 turns."

func split_desc():
	return [
		"For 1 turn, Nagisa ignores all Harmful effects and damage (Invisible)",
		["Any enemy that uses a Harmful skill is Silenced for 2 turns (Invisible)", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Nagisa's self-protection for the turn.
	var non_damage = Effect.ignore_non_damage_effect(2)
	var damage = Effect.ignore_damage_effect(2)
	non_damage.invisible = true
	damage.invisible = true
	damage.wrapup_func = default_counter_timeout
	non_damage.set_source(self)
	damage.set_source(self)
	Character.add_allied_effect(context, user, user, non_damage)
	Character.add_allied_effect(context, user, user, damage)
	# Trap every enemy: any of them that uses a Harmful skill gets Silenced.
	for enemy in context['enemy_team'].characters:
		if enemy.dead or enemy.banished:
			continue
		var trigger = Effect.trigger_effect(Trigger.always(test_me_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 2, "If this character uses a Harmful skill, they are Silenced for 2 turns.")
		trigger.set_source(self)
		trigger.invisible = true
		Character.add_hostile_effect(context, user, enemy, trigger, true)

func test_me_trigger(context):
	# Fires on the enemy who used a Harmful skill (context['target'] == the trap's target).
	var attacker = context['target']
	var nagisa = context['owner']
	if attacker == null or nagisa == null:
		return
	nagisa.manually_advance_mission(9, 1)
	var silence = Effect.silence_effect(5)
	silence.set_source(self)
	Character.add_hostile_effect(context, nagisa, attacker, silence)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	variations += behavior_hostile_aoe_damage(context, 15)

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
