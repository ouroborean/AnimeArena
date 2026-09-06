extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "For 1 turn, Mikasa and her allies cannot be killed. This skill will last 1 additional turn with each use."

func split_desc():
	return [
		["For 1 turn, Mikasa and her allies cannot be killed", Color.CADET_BLUE],
		["Lasts 1 additional turn with each use", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var duration_boost = 0
	var shouty = Condition.has_effect(user, "Rallying Call", EffectType.Type.MARK, user)
	if shouty.satisfied(context):
		duration_boost += user.effects.has_effect("Rallying Call", EffectType.Type.MARK).stack_count()
	user.manually_advance_mission(9, 1 + duration_boost)
	for target in user.targeter.targets:
		var immortal = Effect.immortality_effect(2 + (2 * duration_boost) )
		immortal.set_source(self)
		Character.add_allied_effect(context, user, target, immortal)
	
	var mark = Effect.mark(-1, "Rallying Call will last 1 additional turn per stack.")
	mark.stackable = true
	mark.display_stacks = true
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_helpful_aoe_aid(context, 110)
	
	return variations
		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	default_allied_target_function(user, battle)
