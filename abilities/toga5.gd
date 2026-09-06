extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Toga starts the game disguised as another character (showing their face picture). This effect will end if she takes damage or uses a skill other than Thirsting Knife. While disguised, she gains 1 stack of Twisted Love each turn."

func split_desc():
	return [
		["Toga starts disguised as another character", Color.DIM_GRAY],
		["Disguise ends if she takes damage or uses a skill other than Thirsting Knife", Color.DIM_GRAY],
		["While disguised, Toga gains 1 stack of Twisted Love each turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.disguise_name != "" and user.disguise_name != "toga":
		var disguise = Effect.disguise(user.disguise_name)
		disguise.set_source(self)
		Character.add_allied_effect(context, user, user, disguise)
		var damage_taken = Effect.trigger_effect(Trigger.always(damage_taken_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "If Toga receives damage, she will lose her disguise.")
		damage_taken.invisible = true
		damage_taken.wrapup_func = default_counter_timeout
		damage_taken.set_source(self)
		Character.add_allied_effect(context, user, user, damage_taken)
		var action_trigger = Effect.trigger_effect(Trigger.always(action_use_trigger), EffectType.Type.ACTION_USE_TRIGGER, -1, "If Toga uses a skill other than Thirsting Knife, she will lose her disguise.")
		action_trigger.set_source(self)
		action_trigger.invisible = true
		Character.add_allied_effect(context, user, user, action_trigger)
		var ticking_trigger = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "Toga will gain a stack of Twisted Love.")
		ticking_trigger.set_source(self)
		ticking_trigger.invisible = true
		Character.add_allied_effect(context, user, user, ticking_trigger)

func tick_trigger(context):
	var mark = Effect.mark(-1, func (eff): return "Toga has " + str(eff.stack_count()) + " stacks of Twisted Love.")
	mark.set_source(user.moveset.base_abilities[3])
	mark.invisible = true
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.manually_advance_mission(6, 1)

func damage_taken_trigger(context):
	user.effects.full_remove_effect_by_name("Quirk: Transform")

func action_use_trigger(context):
	if context['source'].ability_name != "Thirsting Knife":
		user.effects.full_remove_effect_by_name("Quirk: Transform")

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
