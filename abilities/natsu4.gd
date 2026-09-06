extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Natsu removes all enemy effects from himself and heals himself 15HP. For each effect removed, Natsu heals 10 more HP and gains 1 stack of I'm all fired up!. This skill swaps to Fire Dragon's Roar for 1 turn for each harmful effect removed."

func split_desc():
	return [
		"Natsu cleanses himself of enemy effects and heals 15 HP",
		["+10 Healing and +1 stack of I'm all fired up! per effect removed", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# cleanse_all_enemy_effects removes every cleansable hostile effect (post-overhaul: no type-gate)
	# and returns how many it stripped, so heal/stacks scale to what was ACTUALLY removed — matching
	# "For each effect removed, Natsu heals 10 more HP and gains 1 stack." (An IGNORE_CLEANSE block
	# returns 0, so Natsu just heals the base 15 with no bonus, which is correct.)
	var hostile_effect_count = user.effects.cleanse_all_enemy_effects(user)
	Character.resolve_healing(context, user, 15 + (10 * hostile_effect_count))
	for i in range(hostile_effect_count):
		var damage_mod_effect = Effect.damage_mod_effect(5, 5, [], [DamageType.Type.AFFLICTION])
		damage_mod_effect.set_source(user.moveset.base_abilities[4])
		Character.add_allied_effect(context, user, user, damage_mod_effect)

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	
	variations += behavior_self_panic_button(context, 15, 1.6)
	
	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_self_target_function(user, battle)
