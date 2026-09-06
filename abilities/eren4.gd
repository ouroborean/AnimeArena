extends Ability

var base_damage = 20

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Eren deals 20 damage to one random enemy and becomes invulnerable for 1 turn. This skill becomes 'Titan Eren Assault' when 'Titan Transformation' activates."

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var valid_targets = []
	for char in battle.all_characters():
		var condition = Condition.can_hostile_target(user, char, self)
		if condition.satisfied(context):
			valid_targets.append(char)
	if len(valid_targets) > 0:
		var target_roll = battle.roll(0, len(valid_targets) - 1)
		var random_target = valid_targets[target_roll]
		Character.resolve_damage(context, random_target, 20, DamageType.Type.NORMAL)
	
	default_defend(user, battle)

func split_desc():
	return [
		"Eren deals 20 damage to a random enemy and becomes Invulnerable for 1 turn",
		["Swaps to Titan Eren Assault when Titan Transformation is active", Color.AQUAMARINE],

	]

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 80, 1.2)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
