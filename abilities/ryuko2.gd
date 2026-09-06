extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Fiber Lost and Life Fiber Synchronization will target all valid characters, but will cost 1 additional random energy. This skill may be used while active to toggle the effect off."

func split_desc():
	return [
		["Fiber Lost and Life Fiber Synchronization target all valid characters", Color.CADET_BLUE],
		["Those skills cost 1 additional random energy", Color.DIM_GRAY],
		["Fiber Lost gains a 1 turn cooldown", Color.DIM_GRAY],
		["May be used while active to toggle the effect off", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.manually_advance_mission(7, 1)
	if user.marked_by("Decapitation Mode", user):
		user.effects.full_remove_effect_by_name("Decapitation Mode", user)
	else:
		var target_change = Effect.target_change_effect(TargetType.Type.ALL, -1, ["Fiber Lost", "Life Fiber Synchronization"])
		target_change.set_source(self)
		var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.RANDOM, ["Fiber Lost", "Life Fiber Synchronization"])
		cost_mod.set_source(self)
		#Fiber Lost ONLY - the target/cost mods above name both skills, this one deliberately does not.
		#start_cooldown always adds its own +1 which advance_cooldowns takes back the same turn, so a
		#mag of 1 lands Fiber Lost on exactly 1 turn of cooldown. Torn down with the rest of the mode
		#by full_remove_effect_by_name, which is keyed on the source ability name.
		var cooldown_mod = Effect.cooldown_mod(1, -1, ["Fiber Lost"])
		cooldown_mod.set_source(self)
		var mark = Effect.mark(-1, "Ryuko can use this skill to toggle it off.")
		mark.set_source(self)
		mark.cleansable = false
		Character.add_allied_effect(context, user, user, target_change)
		Character.add_allied_effect(context, user, user, cost_mod)
		Character.add_allied_effect(context, user, user, cooldown_mod)
		Character.add_allied_effect(context, user, user, mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 0, 0.5)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
