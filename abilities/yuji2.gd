extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Divergent Fist will target two enemies at random the next time it is used (the same enemy can be chosen twice). If Yuji is below 50 HP, Divergent Fist also deals True damage instead of normal damage on its initial hit. Using this skill increases Yuji's chance to trigger Black Flash by 15%."

func split_desc():
	return [
		"Yuji's next Divergent Fist will target two enemies at random",
		"Increases Yuji's chance to trigger Black Flash by 25%",
		["If Yuji's HP is less than 50, the next Divergent Fist will also deal True damage", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var desc = "The next Divergent Fist will target two randomly chosen enemies (the same enemy can be chosen twice)."
	var mag = 0
	if user.health.hp < 50:
		desc = "The next Divergent Fist will deal entirely True damage and target two randomly chosen enemies (the same enemy can be chosen twice)."
		mag = 1
	var mark = Effect.mark(-1, desc)
	mark.set_source(self)
	mark.mag = mag
	Character.add_allied_effect(context, user, user, mark)
	if user.has_effect("Black Flash", EffectType.Type.MARK):
		var flash = user.has_effect("Black Flash", EffectType.Type.MARK)
		flash.mag += 25
		user.manually_advance_mission(8, 15)
		if flash.mag > 100:
			flash.mag = 100
	user.update.emit()

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	if not user.marked_by("Combat Awakening"):
		variations += behavior_self_panic_button(context, 150)
	else:
		variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
