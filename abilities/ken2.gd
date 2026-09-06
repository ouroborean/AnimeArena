extends Ability
var base_damage = 25
#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Kaneki deals 25 piercing damage to one enemy and any bleed currently active on them becomes permanent."

func split_desc():
	return [
		"Deals 25 Piercing damage to target enemy",
		["Any Bleed effect on that enemy becomes permanent", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)

	# While Bloodthirsty Rampage is active, Disembowel strikes 2 random enemies
	# (mirrors Tentacle Pierce / ken1.gd).
	if user.marked_by("Bloodthirsty Rampage"):
		var valid_targets = []
		for character in context['enemy_team'].characters:
			if not character.dead and not character.banished and not character.is_invuln(self):
				valid_targets.append(character)
		if len(valid_targets) > 0:
			var roll = user.battle.roll(0, len(valid_targets) - 1)
			var random_target1 = valid_targets[roll]

			var roll2 = user.battle.roll(0, len(valid_targets) - 1)
			var random_target2 = valid_targets[roll2]
			user.targeter.clear_targets()
			user.targeter.targets.append(random_target1)
			user.targeter.targets.append(random_target2)
		else:
			return

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage, DamageType.Type.PIERCING)
		for effect in target.effects.get_effects_by_type(EffectType.Type.DAMAGE):
			if effect.damage_type == DamageType.Type.BLEED:
				user.manually_advance_mission(10, 1)
				effect.last_turn_only = false
				effect.set_duration(-1)


func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []

	if user.marked_by("Bloodthirsty Rampage"):
		variations += behavior_self_panic_button(context, 100)
	else:
		variations += behavior_single_target_damage(context, 35)

	return variations

func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	if user.marked_by("Bloodthirsty Rampage"):
		default_self_target_function(user, battle)
	else:
		default_hostile_target_function(user, battle)
