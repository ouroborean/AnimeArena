extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Shokuhou takes 10 Affliction damage and increases the cost of all of her skills by 1 White energy until she uses a new skill",
		["While active, her next skill has its duration increased by 2 turns", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_damage(context, user, 10, DamageType.Type.AFFLICTION)
	var mark = Effect.mark(-1, "Shokuhou's next skill will last 2 more turns.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var cost_mod = Effect.cost_mod_effect(1, -1, Energy.Type.WHITE)
	cost_mod.set_source(self)
	Character.add_allied_effect(context, user, user, cost_mod)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return not user.marked_by("Exterior")
	
func custom_behavior(context):
	var variations = []
	if user.marked_by("exterior"):
		variations.append([0, [user, "PASS", []]])
		return variations
	variations += behavior_self_panic_button(context, 35)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
