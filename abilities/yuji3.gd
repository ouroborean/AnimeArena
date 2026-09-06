extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Yuji heals himself for 15 HP, permanently increases the initial damage dealt by Divergent Fist by 5, and permanently increases the minimum chance for Black Flash to activate by 15%."

func split_desc():
	return [
		["Yuji heals himself for 15 HP", Color.CADET_BLUE],
		["Permanently increases Divergent Fist's initial damage by 5", Color.CADET_BLUE],
		["Permanently increases Black Flash's minimum and current activation chance by 15%", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_healing(context, user, 15)
	
	if user.has_effect("Black Flash", EffectType.Type.MARK):
		user.black_flash_minimum += 15
		if user.black_flash_minimum > 100:
			user.black_flash_minimum = 100
		var flash = user.has_effect("Black Flash", EffectType.Type.MARK)
		# The CURRENT chance must rise by exactly 15 as well. The old form only pulled current UP TO
		# the new floor, so a Yuji sitting on his minimum gained 15 by accident while a Yuji above it
		# gained nothing at all. Add the 15 outright — and do NOT then also snap current to the new
		# floor, which is the obvious-looking fix and would pay the same 15 twice. The floor stays a
		# lower bound only; 100 is the ceiling, and this is the one chance site that never clamped.
		var raised = flash.mag + 15
		if raised < user.black_flash_minimum:
			raised = user.black_flash_minimum
		if raised > 100:
			raised = 100
		user.manually_advance_mission(8, raised - flash.mag)
		flash.mag = raised
	var mark = Effect.mark(-1, "Divergent Fist will deal 5 more initial damage.")
	mark.set_source(self)
	mark.stackable = true
	mark.display_stacks = true
	Character.add_allied_effect(context, user, user, mark)
	user.update.emit()

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 25, 2.5)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
