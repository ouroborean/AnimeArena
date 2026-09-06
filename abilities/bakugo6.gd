extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "This skill triggers each time Bakugou uses a new non-Strategic skill. He gains 5 additional damage permanently."

func split_desc():
	return [
		"Whenever Bakugou uses a non-Strategic skill, he gets +5 damage permanently (stacks)",
		"Stacks are reset when Hauser Impact is used"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "If Bakugou uses a new non-Strategic skill, he will permanently deal 5 more damage."
	var trigger = Trigger.from_condition(Condition.always(), storage_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.ACTION_USE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	trigger_eff.waiting = false
	Character.add_allied_effect(context, user, user, trigger_eff)

func storage_trigger(context):
	var ability = context['owner'].used_ability
	if ability.classes["Strategic"]:
		return
	if ability.ability_name == "Hauser Impact":
		user.effects.remove_effect("Nitroglycerin Storage", EffectType.Type.DAMAGE_MOD, user)
		return
	var damage_buff = Effect.damage_mod_effect(5, -1)
	damage_buff.set_source(self)
	damage_buff.stackable = true
	damage_buff.per_stack = true
	damage_buff.display_stacks = true
	Character.add_allied_effect(context, user, user, damage_buff, true)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	pass
