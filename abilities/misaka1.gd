extends Ability
var base_shield = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Misaka grants one ally 20 points of Shield for 1 turn. After being used, this ability will be replaced by Iron Colossus for 1 turn."

func split_desc():
	return [
		"Grants one ally 20 Shield for 1 turn",
		["+5 Shield per stack of Overcharge", Color.CADET_BLUE],
		["Replaced by Iron Colossus for 1 turn after use", Color.AQUA]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var mod_shield = base_shield
	
	if user.marked_by("Ultra Railgun", user):
		mod_shield = mod_shield * 2
	
	if user.has_effect("Overcharge", EffectType.Type.EMPTY, user):
		mod_shield += 5 * user.has_effect("Overcharge", EffectType.Type.EMPTY, user).stacks
	
	for target in user.targeter.targets:
		var shield = Effect.shield_effect(mod_shield, 2)
		shield.stackable = false
		shield.set_source(self)
		Character.add_allied_effect(context, user, target, shield)
	if not user.marked_by("Ultra Railgun", user) and not user.marked_by("Iron Colossus", user):
		var swap = Effect.ability_swap_effect(4, 0, user, 3)
		swap.set_source(self)
		Character.add_allied_effect(context, user, user, swap)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	if target_type() == TargetType.Type.SINGLE:
		variations += behavior_single_target_helpful(context, 25)
	else:
		variations += behavior_helpful_aoe_aid(context, 45, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
