extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Deals 30 Piercing damage to target enemy and Ai gains 1 Random energy for each dead ally on her team. Has its Green cost changed to Random for 2 turns after using Weapon: Pen-Lights. Has its Red cost changed to Random for 2 turns after using Weapon: Gymnastics Ribbon."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		["Ai gains 1 Random energy for each dead ally on her team", Color.CADET_BLUE],
		["Green cost becomes Random for 2 turns after Weapon: Pen-Lights; Red cost becomes Random for 2 turns after Weapon: Gymnastics Ribbon", Color.DIM_GRAY]
	]

# Conditional cost: after Weapon: Pen-Lights, Green -> Random; after Weapon: Gymnastics Ribbon, Red -> Random.
# Each of those skills leaves a same-named MARK on Ai (dur 2 turns) that this reads.
func cost():
	var output = super.cost()
	if user == null:
		return output
	if user.has_effect("Weapon: Pen-Lights", EffectType.Type.MARK, user):
		output[0] = 0
		output[4] = output.get(4, 0) + 1
	if user.has_effect("Weapon: Gymnastics Ribbon", EffectType.Type.MARK, user):
		output[3] = 0
		output[4] = output.get(4, 0) + 1
	return output

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var dead_allies = 0
	for c in context['ally_team'].characters:
		if c.dead:
			dead_allies += 1
	for i in range(dead_allies):
		user.gain_random_energy()   # RANDOM isn't a storable color; roll a real color per dead ally

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, 30, DamageType.Type.PIERCING)
		# Achievement: Ai Reset — killing an enemy with this skill heals Ai, grants Immortality, and
		# resets this skill's cooldown. (The Pen-Light Charges follow-up damage is applied synchronously
		# during resolve_damage, so target.dead already reflects it here.)
		if target.dead:
			Character.resolve_healing(context, user, 10)
			var immortal = Effect.immortality_effect(2)
			immortal.set_source(user.moveset.base_abilities[5])
			Character.add_allied_effect(context, user, user, immortal)
			cooldown_remaining = 0

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 60)
	return variations

func target(user, battle):
	default_hostile_target_function(user, battle)
