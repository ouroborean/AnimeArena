extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Killua deals 20 piercing damage to one enemy, stuns them for 1 turn, and gives them 1 stack of Decapitation."

func split_desc():
	return [
		"Deals 20 piercing damage to target enemy",
		"Stuns them for 1 turn",
		"Applies 1 stack of Decapitation"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		var mark_desc = func (eff):
			return "This character has " + str(eff.stack_count()) + " stacks of Decapitation."
		var mark = Effect.mark(-1, mark_desc)
		mark.stackable = true
		mark.display_stacks = true
		mark.set_source(user.moveset.base_abilities[2])
		Character.add_hostile_effect(context, user, target, mark)
		var stun = Effect.stun_effect(2)
		stun.set_source(self)
		Character.add_hostile_effect(context, user, target, stun)
		
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_stun(context, 75)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
