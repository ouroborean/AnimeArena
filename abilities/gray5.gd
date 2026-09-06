extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "The first time Gray's health reaches 30 or below, he will permanently gain the effects of Ice, Make... and Ice, Make Shield will be replaced by Iced Shell."

func split_desc():
	return [
		"The first time Gray's health falls to 30 or below, he permanently gains the effects of Ice, Make...",
		["Ice, Make Shield is then permanently replaced by Iced Shell", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var trigger_desc = func (eff):
		return "If Gray's health falls to 30 or below, he will permanently gain the effects of Ice, Make... and it will be replaced by Iced Shell."
	var trigger = Trigger.from_condition(Condition.health_is(user, -1, 30), disciple_trigger)
	var trigger_eff = Effect.trigger_effect(trigger, EffectType.Type.HEALTH_CHANGE_TRIGGER, -1, trigger_desc)
	trigger_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, trigger_eff)

func disciple_trigger(context):
	var gray = context['owner']
	gray.effects.full_remove_effect_by_name("Disciple of Ur", gray)
	var stun_ign = Effect.ignore_effect_effect(-1, EffectType.Type.STUN)
	stun_ign.set_source(gray.moveset.base_abilities[0])
	stun_ign.cleansable = false
	var mark = Effect.mark(-1, "Gray can use his skills.")
	mark.set_source(gray.moveset.base_abilities[0])
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, stun_ign)
	Character.add_allied_effect(context, user, user, mark)
	
	if gray.has_effect("Ice, Make Unlimited", EffectType.Type.MARK, gray):
		var abi_swap = Effect.ability_swap_effect(7, 0, gray, 3)
		abi_swap.set_source(gray.moveset.base_abilities[0])
		Character.add_allied_effect(context, gray, gray, abi_swap)
	else:
		var abi_swap = Effect.ability_swap_effect(5, 0, gray, 3)
		abi_swap.set_source(gray.moveset.base_abilities[0])
		Character.add_allied_effect(context, gray, gray, abi_swap)
	
	var abi_swap = Effect.ability_swap_effect(6, 3, gray, -1)
	abi_swap.set_source(self)
	Character.add_allied_effect(context, gray, gray, abi_swap)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
