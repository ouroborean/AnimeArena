extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Ganta uses or receives a Harmful skill, he takes 3 affliction damage per turn for 5 turns."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger = Effect.trigger_effect(Trigger.always(woodpecker_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "If Ganta uses a new harmful skill, he will take 5 affliction damage for 3 turns.")
	trigger.set_source(self)
	trigger.waiting = false
	var trigger2 = Effect.trigger_effect(Trigger.always(woodpecker_trigger), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "If Ganta receives a new harmful skill, he will take 5 affliction damage for 3 turns.")
	trigger2.set_source(self)
	trigger2.waiting = false
	Character.add_allied_effect(context, user, user, trigger)
	Character.add_allied_effect(context, user, user, trigger2)
	

func split_desc():
	return [
		"Ganta takes 5 Affliction damage for 3 turns whenever he uses or receives a Harmful skill"
	]

func woodpecker_trigger(context):
	var eff = context['source']
	
	#3 turns of damage INCLUDING the trigger turn: the manual instance below is turn 1, so the ticker
	#runs 2N-1 = 5. (The old numbers were the same shape for 5 turns: 2*5-1 = 9.)
	var damage_eff = Effect.damage_effect(5, DamageType.Type.AFFLICTION, 5)
	damage_eff.set_source(self)
	damage_eff.unique_render_id = int(Time.get_ticks_msec())
	Character.add_allied_effect(context, user, user, damage_eff)
	Character.resolve_effect_damage(context, damage_eff, user, 5, DamageType.Type.AFFLICTION)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
