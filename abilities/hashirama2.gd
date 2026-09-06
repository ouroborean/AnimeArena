extends Ability
var base_damage = 20
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Target enemy takes 20 damage and is stunned for 1 turn. This skill is always delayed by 1 turn. While enhanced, this skill will stun a random targetable enemy's Physical and Energy skills each turn that it remains delayed."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		"Stuns them for 1 turn",
		["Always delayed by 1 turn", Color.DIM_GRAY],
		["While enhanced, stuns a random enemy's Physical and Energy skills each turn it stays delayed", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	if user.marked_by("Deep Forest Creation", user):
		user.manually_advance_mission(9, 1)

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		
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
	
	variations += behavior_single_target_stun(context, 50)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
