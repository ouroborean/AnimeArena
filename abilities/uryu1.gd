extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Uryuu gains 4 Quincy Energy. As long as he has Quincy Energy remaining, this skill will be replaced by 'Quincy Final Kojaku Shot'."

func split_desc():
	return [
		["Uryuu gains 4 Quincy Energy", Color.CADET_BLUE],
		["While he has Quincy Energy, swaps with Quincy Final Kojaku Shot", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mark_desc = func (eff):
		return "Uryu has " + str(eff.mag) + " Quincy Energy."
	var mark_eff = Effect.from(EffectType.Type.MARK, {"description": mark_desc, "mag": 4, "duration": -1})
	mark_eff.set_source(self)
	
	var swap_eff = Effect.ability_swap_effect(4, 0, user, -1)
	swap_eff.set_source(self)
	
	Character.add_allied_effect(context, user, user, mark_eff)
	Character.add_allied_effect(context, user, user, swap_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 250)
	
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
