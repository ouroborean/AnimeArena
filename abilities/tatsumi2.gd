extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 3 turns, Tatsumi gains 10 points of Damage Reduction and becomes Invulnerable at the end of any turn where he doesn't use a new skill. During this time, Neuntote is usable, Killing Strike becomes Piercing damage and Tatsumi's skills will Bypass while he is Invulnerable."

func split_desc():
	return [
		["Tatsumi gains 10 damage reduction for 3 turns", Color.CADET_BLUE],
		["Becomes invulnerable at the end of any turn where he doesn't use a new skill", Color.CADET_BLUE],
		["Neuntote is usable", Color.DIM_GRAY],
		["Killing Strike becomes Piercing damage", Color.DIM_GRAY],
		["Tatsumi's skills Bypass while he is invulnerable", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dr = Effect.damage_reduction_effect(10, 6)
	dr.set_source(self)
	var mark = Effect.mark(5, "Tatsumi's skills will Bypass while he is Invulnerable.")
	mark.set_source(self)
	var empty = Effect.empty(5, "Neuntote is usable.")
	empty.set_source(self)
	var trigger = Effect.trigger_effect(Trigger.always(incursio_trigger), EffectType.Type.END_OF_TURN_TRIGGER, 5, "Tatsumi will become Invulnerable for 1 turn after not using any skills.")
	trigger.set_source(self)
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, empty)
	Character.add_allied_effect(context, user, user, mark)
	Character.add_allied_effect(context, user, user, dr)
	

func incursio_trigger(context):
	if context['target'].acted:
		return
	if context['target'].has_effect("Incursio", EffectType.Type.INVULN):
		return
	var invuln = Effect.invuln_effect(3)
	invuln.set_source(self)
	Character.add_allied_effect(context, context['target'], context['target'], invuln)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 125, 1.5)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
