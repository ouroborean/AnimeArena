extends Ability
var base_boost = 10
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Grants an ally 10 more non-affliction damage until the end of the turn. Next turn, Defensive Alchemy has no cost, but grants 10 less Shield/Nullify."

func split_desc():
	return [
		"Gives target ally +10 non-Affliction damage until the end of the turn",
		"Defensive Alchemy has no cost but gives -10 Shield/Nullify for 1 turn"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var boost = Effect.damage_mod_effect(10, 1, [], [], [DamageType.Type.AFFLICTION], [])
		boost.set_source(self)
		Character.add_allied_effect(context, user, target, boost)
	var cost_change = Effect.cost_change_effect({}, 3, ["Defensive Alchemy"])
	cost_change.set_source(self)
	var cost_mark = Effect.mark(3, func (eff): return "Defensive Alchemy will give 10 less Shield/Nullify.")
	cost_mark.set_source(self)
	Character.add_allied_effect(context, user, user, cost_change)
	Character.add_allied_effect(context, user, user, cost_mark)
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_helpful(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_allied_target_function(user, battle)
