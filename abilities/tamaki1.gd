extends Ability

var base_damage = 10
var base_per_dot = 5

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tamaki deals 10 affliction damage to one enemy, increased by 5 for every damage over time effect on them. If the target is affected by Nekomata Cage, this skill Bypasses Invulnerability. Afterwards, causes the enemy to take 5 affliction damage permanently, stacking."

func split_desc():
	return [
		"Deals 10 affliction damage to one enemy, +5 per damage over time effect on them",
		["Bypasses invulnerability if target is affected by Nekomata Cage", Color.ORANGE_RED],
		["Causes the enemy to take 5 affliction damage permanently (stacks)", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	
	var dot_multi = base_per_dot
	
	for target in user.targeter.targets:
		var dots = target.effects.get_effects_by_type(EffectType.Type.DAMAGE)
		var dot_count = 0
		for dot in dots:
			if dot.per_stack:
				dot_count += dot.stacks
			else:
				dot_count += 1
		Character.resolve_damage(context, target, base_damage + (dot_multi * dot_count), DamageType.Type.AFFLICTION)
		var damage_effect = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1)
		damage_effect.set_source(self)
		damage_effect.stackable = true
		damage_effect.remove_on_death = false
		damage_effect.per_stack = true
		damage_effect.display_stacks = true
		Character.add_hostile_effect(context, user, target, damage_effect, target.marked_by("Nekomata Cage", user))

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func target(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for character in battle.all_characters():
		if character.marked_by("Nekomata Cage", user):
			check_hostile_target(user, character, context, true)
		else:
			check_hostile_target(user, character, context)
