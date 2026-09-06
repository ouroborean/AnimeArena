extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"For 4 turns, another ally wields Tsubaki and Tsubaki gains 10 Damage Reduction",
		["Wielding ally changes their White costs to Random", Color.CADET_BLUE],
		["Wielding ally Bypasses Invulnerability", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var wield_eff = Effect.mark(8, "This character is wielding Tsubaki.")
		wield_eff.set_source(self)
		var boost_eff = Effect.empty(8, "This character's effect will Bypass Invulnerability")
		boost_eff.set_source(self)
		var color_change = Effect.color_change_effect(Energy.Type.RANDOM, Energy.Type.WHITE, 8)
		color_change.set_source(self)
		
		Character.add_allied_effect(context, user, target, wield_eff)
		Character.add_allied_effect(context, user, target, boost_eff)
		Character.add_allied_effect(context, user, target, color_change)

	var percent_dr = Effect.damage_reduction_effect(10, 8)
	percent_dr.set_source(self)
	Character.add_allied_effect(context, user, user, percent_dr)
		
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
	var context = QueryContext.from_game_state(user, battle)
	var partnered = Condition.has_effect(user, "Partner: Black Star", EffectType.Type.MARK, user)
	if not partnered.satisfied(context):
		default_allied_target_function(user, battle)
	else:
		for character in user.team.characters:
			if character.path_name == "blackstar":
				check_allied_target(user, character, context)
