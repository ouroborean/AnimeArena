extends Ability

var base_damage = 45

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 45 Piercing damage to one enemy. For the rest of the game, Midoriya's skills will make him Invulnerable for 1 turn and Bypass Invulnerability."

func split_desc():
	return [
		"Deals 45 Piercing damage to target enemy",
		["For the rest of the game, Midoriya's skills make him Invulnerable for 1 turn and Bypass Invulnerability", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var faux = Condition.has_effect(user, "Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
	if not faux.satisfied(context):
		var trigger = Effect.trigger_effect(Trigger.always(faux_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "Midoriya's skills Bypass Invulnerability. If he uses a new skill, he will also become Invulnerable for 1 turn.")
		trigger.set_source(self)
		Character.add_allied_effect(context, user, user, trigger)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func faux_trigger(context):
	var invuln = Effect.invuln_effect(2)
	invuln.set_source(self)
	Character.add_allied_effect(context, context['owner'], context['owner'], invuln)

func custom_behavior(context):
	var variations = []
	var midoriya = context['owner']
	if midoriya.has_effect("Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, midoriya):
		variations += behavior_single_target_damage(context, 75, 1.0, true)
	else:
		variations.append([125, [midoriya, self, [midoriya]]])
	
	return variations

func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var faux = Condition.has_effect(user, "Faux 100%", EffectType.Type.ACTION_USE_TRIGGER, user)
	var bypassing = false
	if faux.satisfied(context):
		bypassing = true
	default_hostile_target_function(user, battle, bypassing)
