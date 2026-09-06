extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Edward becomes Invulnerable for 1 turn. After being used, for the next 4 turns this skill can be used to deal 20 piercing damage to one enemy."

func split_desc():
	return [
		"Edward becomes Invulnerable for 1 turn",
		["For the next 4 turns, can be used to deal 20 Piercing damage to one enemy", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	if not user.marked_by("Fullmetal Alchemy", user):
		default_defend(user, battle)
		var mark = Effect.mark(9, func (eff): return "Fullmetal Alchemy can be used to deal 20 piercing damage to one enemy.")
		mark.set_source(self)
		Character.add_allied_effect(context, user, user, mark)
	else:
		for target in user.targeter.targets:
			Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	var user = context['owner']
	if not user.marked_by("Fullmetal Alchemy", user):
		variations += behavior_self_panic_button(context, 100, 1.1)
	else:
		variations += behavior_single_target_damage(context, 35, 1.3)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	
	if user.marked_by("Fullmetal Alchemy", user):
		default_hostile_target_function(user, battle)
	else:
		default_self_target_function(user, battle)
