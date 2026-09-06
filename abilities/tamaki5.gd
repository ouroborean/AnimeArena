extends Ability
var base_damage = 30
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Tamaki deals 30 affliction damage to one target, increased by 5 for every damage over time effect on them. If the target is affected by Nekomata Cage, this skill ignores invulnerability. Afterwards, applies three stacks of 5 permanent affliction damage to the enemy."

func split_desc():
	return [
		"Deals 30 affliction damage to one target, +5 per damage over time effect on them",
		["Ignores invulnerability if target is affected by Nekomata Cage", Color.ORANGE_RED],
		["Applies three stacks of 5 permanent affliction damage to the enemy", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var dots = target.effects.get_effects_by_type(EffectType.Type.DAMAGE)
		var dot_count = 0
		for dot in dots:
			if dot.per_stack:
				dot_count += dot.stacks
			else:
				dot_count += 1
		
		Character.resolve_damage(context, target, base_damage + (5 * dot_count), DamageType.Type.AFFLICTION)
		
		for i in range(3):
			var damage_effect = Effect.damage_effect(5, DamageType.Type.AFFLICTION, -1)
			damage_effect.set_source(self)
			damage_effect.stackable = true
			damage_effect.per_stack = true
			damage_effect.display_stacks = true
			damage_effect.remove_on_death = false
			Character.add_hostile_effect(context, user, target, damage_effect)

func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 125, 0.5)
	
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
