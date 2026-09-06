extends Ability
var base_healing = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "When Nezuko reaches 50HP for the first time, she will heal 10HP every turn for 5 turns."

func split_desc():
	return [
		["The first time Nezuko's health falls to 50 or below, she heals 10 HP each turn for 5 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var health_trigger_eff = Effect.trigger_effect(Trigger.from_condition(Condition.health_is(user, -1, 50), blood_trigger), EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, "The first time Nezuko's health reaches 50 or lower, she will heal 10 health each turn for 5 turns.")
	health_trigger_eff.set_source(self)
	Character.add_allied_effect(context, user, user, health_trigger_eff)
	
func blood_trigger(context):
	var user = context['owner']
	
	user.effects.remove_effect("Demon Blood", EffectType.Type.HEALTH_CHANGE_TRIGGER, user)
	
	var heal_eff = Effect.healing_effect(base_healing, 10)
	heal_eff.set_source(self)
	Character.add_allied_effect(context, user, user, heal_eff)
	

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
