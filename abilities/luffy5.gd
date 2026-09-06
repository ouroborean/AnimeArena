extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Whenever Luffy deals damage to an enemy, he will gain 15 Shield for 1 turn."

func split_desc():
	return [
		["Whenever Luffy deals damage to an enemy, he gains 15 Shield for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var trigger_desc = func (eff):
		return "Whenever Luffy deals damage to an enemy, he will gain 15 Shield for 1 turn."
	var trigger = Trigger.from_condition(Condition.always(), rubber_body_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.DAMAGE_DEALT_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)

	
	Character.add_allied_effect(context, user, user, trigger_eff)

func rubber_body_trigger(context):
	var shield_eff = Effect.shield_effect(15, 2)
	shield_eff.set_source(self)
	
	Character.add_allied_effect(context, context['effect'].user, context['effect'].user, shield_eff)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return false
	
func target(user, battle):
	pass
