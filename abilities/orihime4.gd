extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Orihime cleanses herself of enemy effects and ignores negative non-damage effects for 1 turn",
		["The following turn, her skills are Empowered", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	user.effects.cleanse_all_enemy_effects(user)
	var mark = Effect.mark(3, "Orihime's skills are Empowered.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)
	var ignore = Effect.ignore_non_damage_effect(2)
	ignore.set_source(self)
	Character.add_allied_effect(context, user, user, ignore)
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, 3, ["Solitary Sacred Cutting Shield"])
	target_change.set_source(self)
	target_change.system = true
	Character.add_allied_effect(context, user, user, target_change)
	
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 45)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
