extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Sukuna deals 5 damage to all other characters, and permanently afflicts them with an effect that deals 5 damage each turn. This skill can be used repeatedly; each use adds another stack, and every stack deals its damage separately each turn."

func split_desc():
	return [
		"Deals 5 damage to all other characters",
		"Permanently deals 5 damage per turn",
		"Reusable: each use adds a stack",
		"Requires Malevolent Shrine"
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 5, DamageType.Type.NORMAL)
		# A real DAMAGE effect (not a TICKING_TRIGGER): per_stack is only consumed by the battle
		# scene's ticking handler for DAMAGE/HEALING, where it deals mag once PER STACK.
		# add_effect merges on (effect_name, effect_type, user), and because the resident copy is
		# stackable it absorbs the new one as +1 stack instead of creating a duplicate effect.
		# stack_mag is deliberately NOT set — mag must stay 5 so N stacks tick N x 5, not N x 5N.
		var tick = Effect.damage_effect(5, DamageType.Type.NORMAL, -1)
		tick.set_source(self)
		tick.stackable = true
		tick.display_stacks = true
		tick.per_stack = true
		tick.cleansable = true
		tick.description = func (eff):
			return "This character will take " + str(eff.mag * eff.stack_count()) + " damage."
		Character.add_hostile_effect(context, user, target, tick)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return user.marked_by("Malevolent Shrine")

func custom_behavior(context):
	var variations = []

	variations += behavior_all_target(context, 150)

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
