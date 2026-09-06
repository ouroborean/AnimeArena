extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, the first time Boruto receives a new Harmful skill, he will become Invulnerable for the rest of the turn (Invisible)",
		["The enemy that triggers this effect receives 15 Piercing damage", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(harmful_receive_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, 2, "Boruto will deal 15 Piercing damage to the first enemy to use a Harmful skill on him and become Invulnerable for the rest of the turn.")
	trigger.set_source(self)
	trigger.invisible = true
	trigger.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, trigger)

func harmful_receive_trigger(context):
	var boruto = context.target
	var enemy = context.owner
	Character.resolve_effect_damage(context, context.effect, enemy, 15, DamageType.Type.PIERCING)
	var invuln = Effect.invuln_effect(1)
	invuln.set_source(self)
	Character.add_allied_effect(context, boruto, boruto, invuln)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
