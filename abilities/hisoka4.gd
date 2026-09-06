extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 1 turn, Hisoka will ignore any Harmful skill used on him (Invisible)",
		["This skill is replaced by Bungee Gum - Reflect on the following turn", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var non_damage = Effect.ignore_non_damage_effect(2)
		var damage = Effect.ignore_damage_effect(2)
		non_damage.system=true
		damage.invisible=true
		damage.wrapup_func = default_counter_timeout
		non_damage.set_source(self)
		non_damage.description = func (eff): return "Hisoka will ignore all Harmful skills used on him."
		damage.set_source(self)
		var mark = Effect.mark(3, "Any Harmful skill used on Hisoka will become captured in Bungee Gum.")
		mark.set_source(self)
		mark.invisible = true
		var swap = Effect.ability_swap_effect(4, 3, user, 3)
		swap.set_source(self)
		swap.invisible = true
		Character.add_allied_effect(context, user, user, swap)
		Character.add_allied_effect(context, user, user, mark)
		Character.add_allied_effect(context, user, user, non_damage)
		Character.add_allied_effect(context, user, user, damage)
	for enemy in context.enemy_team.characters:
		var harmful_trigger = Effect.trigger_effect(Trigger.always(use_trigger), EffectType.Type.HARMFUL_USE_TRIGGER, 2, "")
		harmful_trigger.set_source(self)
		Character.add_hostile_effect(context, user, enemy, harmful_trigger, true)

func use_trigger(context):
	if user in context.target.targeter.targets:
		var gum = user.has_effect("Bungee Gum - Catch", EffectType.Type.MARK)
		if gum:
			gum.class_targets.append(context.target.used_ability)
			var stored_string = ""
			for ability in gum.class_targets:
				stored_string += ability.ability_name + ", "
			stored_string = stored_string.substr(0, len(stored_string) - 2)
			gum.description = func (eff): return "Hisoka has stored: " + stored_string




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
	default_self_target_function(user, battle)
