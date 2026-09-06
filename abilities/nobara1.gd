extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Deals 20 damage to target enemy and permanently increases the damage they take from this skill by 5 (stacks)."

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["Permanently increases the damage they take from this skill by 5 (stacks)", Color.ORANGE_RED],
		["During Resonance, also stuns a random skill class", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var base_damage = 20
		if target.marked_by("Hammer Swing"):
			var swings = target.has_effect("Hammer Swing", EffectType.Type.MARK).stacks
			base_damage += (5 * swings)
		Character.resolve_damage(context, target, base_damage, DamageType.Type.NORMAL)
		var mark = Effect.mark(-1, "This character will receive 5 more damage from Hammer Swing.")
		mark.set_source(self)
		mark.stackable = true
		mark.display_stacks = true
		Character.add_hostile_effect(context, user, target, mark)
		if user.marked_by("Resonance"):
			var classes_available = user.has_effect("Resonance", EffectType.Type.MARK).ability_targets
			var roll = battle.roll(0, len(classes_available) - 1)
			var chosen_class = classes_available[roll]
			user.has_effect("Resonance", EffectType.Type.MARK).ability_targets.erase(chosen_class)
			var stun = Effect.stun_effect(2, [chosen_class])
			stun.set_source(user.moveset.abilities[2])
			Character.add_hostile_effect(context, user, target, stun)
			if target.marked_by("Straw Doll Technique"):
				user.manually_advance_mission(10, 1)

		
func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations += behavior_single_target_damage(context, 75)
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
