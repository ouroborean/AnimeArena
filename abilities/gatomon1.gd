extends Ability
var base_damage = 15
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Gatomon deals 15 damage to 1 enemy and Blinds their Helpful skills for 1 turn. Gatomon gains 1 stack of 'Digivolution'."

func split_desc():
	return [
		"Deals 15 damage to target enemy and Blinds their Helpful skills for 1 turn",
		"Gatomon gains 1 stack of Digivolution"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var blind = Effect.blind_effect(2, ["Helpful"])
		blind.set_source(self)
		Character.add_hostile_effect(context, user, target, blind)
	
	var digi_stack = Effect.mark(-1, func (eff): return "Gatomon has " + str(eff.stack_count()) + " stacks of Digivolution.")
	digi_stack.set_source(user.moveset.base_abilities[2])
	digi_stack.stackable = true
	digi_stack.display_stacks = true
	Character.add_allied_effect(context, user, user, digi_stack)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_hostile(context, 25)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
