extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return "Mikasa and another ally ignore Harmful, non-damage effects for 1 turn. Swaps to 'Thunder Spear' while active. This effect is invisible."

func split_desc():
	return [
		"Mikasa and another ally ignore negative non-damage effects for 1 turn",
		["Swaps to Thunder Spear while active", Color.AQUAMARINE],
		["Invisible", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		var dodge_eff = Effect.ignore_non_damage_effect(2)
		dodge_eff.set_source(self)
		dodge_eff.invisible = true
		dodge_eff.wrapup_func = default_counter_timeout
		Character.add_allied_effect(context, user, target, dodge_eff)
	var swap_eff = Effect.ability_swap_effect(4, 2, user, 3)
	swap_eff.set_source(self)
	swap_eff.invisible = true
	Character.add_allied_effect(context, user, user, swap_eff)
	var dodge_eff = Effect.ignore_non_damage_effect(2)
	dodge_eff.set_source(self)
	dodge_eff.invisible = true
	dodge_eff.wrapup_func = default_counter_timeout
	Character.add_allied_effect(context, user, user, dodge_eff)
	



func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true

func custom_behavior(context):
	var variations = []
	var user = context['owner']
	for character in context['ally_team'].characters:
		if (not character.is_isolated()) and not (character.dead or character.banished) and not character == user:
			var missing_hp = 100 - character.health.hp
			variations.append([100 + int(missing_hp * 1.2), [user, self, [character]]])
	if len(variations) == 0:
		variations.append([0, [user, "PASS", []]])
	
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
