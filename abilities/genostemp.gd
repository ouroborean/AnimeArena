extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Genos fully stuns himself for 1 turn. When this skill ends all enemies and allies will recieve affliction damage equal to Genos' current health then he will die."

func split_desc():
	return [
		"Stuns Genos for 1 turn. After this effect ends, deals Affliction damage to all enemies and allies equal to Genos' HP",
		"Afterward, Genos dies"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var stun = Effect.stun_effect(3)
	stun.set_source(self)
	var trigger = Effect.trigger_effect(Trigger.always(self_destruct_trigger), EffectType.Type.TICKING_TRIGGER, 3, "When this skill ends, all enemies and allies will receive Affliction damage equal to Genos' current health, then he will die.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, stun)

func self_destruct_trigger(context):
	var user = context['owner']
	for character in user.battle.all_characters():
		if not character == user:
			var invuln = Condition.is_invuln(character, self)
			if not invuln.satisfied(context) and not (character.dead or character.banished):
				Character.resolve_effect_damage(context, context['effect'], character, user.health.hp, DamageType.Type.AFFLICTION)
	user.instant_kill(user, self)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0, 3.0)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_self_target_function(user, battle)
