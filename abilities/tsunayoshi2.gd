extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, the first enemy to use a new Affliction or Energy skill on Tsuna is countered and stunned for 1 turn. If this move successfully counters an ability, X-Burner will deal 10 additional damage to all targets for 2 turns."

func split_desc():
	return [
		["For 1 turn, counters and stuns for 1 turn the first enemy to use a new Affliction or Energy skill on Tsuna", Color.ORANGE_RED],
		["On a successful counter, X-Burner deals 10 additional damage to all targets for 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var counter_eff = Effect.counter_effect(Trigger.always(breakthrough_trigger), EffectType.Type.COUNTER_RECEIVE, 2, "Tsuna will counter the first Energy or Affliction skill used on him.", ["Energy", "Affliction"])
	counter_eff.set_source(self)
	counter_eff.invisible = true
	counter_eff.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, counter_eff)

func breakthrough_trigger(context):
	var countered_target = context['owner']
	var counter_eff_target = context['target']
	var counter_user = context['effect'].user
	
	var stun_effect = Effect.stun_effect(3)
	stun_effect.set_source(self)
	Character.add_hostile_effect(context, counter_user, countered_target, stun_effect)
	
	var damage_mod = Effect.damage_mod_effect(10, 4, ["X-Burner"])
	damage_mod.set_source(self)
	Character.add_allied_effect(context, counter_user, counter_user, damage_mod)
	
	default_counter_trigger(context)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
