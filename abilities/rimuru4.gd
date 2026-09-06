extends Ability
var base_healing = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Rimuru ignores negative non-damage effects and heals 15 health for 2 turns. While active, this swaps to 'Demon Summon' and it is the only skill that may be used."

func split_desc():
	return [
		"For 2 turns, Rimuru ignores negative non-damage effects and heals 15 HP each turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_healing(context, user, base_healing)
	var harmful_ignore = Effect.ignore_non_damage_effect(4)
	harmful_ignore.set_source(self)
	var heal_eff = Effect.healing_effect(15, 3)
	heal_eff.set_source(self)
	Character.add_allied_effect(context, user, user, harmful_ignore)
	Character.add_allied_effect(context, user, user, heal_eff)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 35, 1.2)
	
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
