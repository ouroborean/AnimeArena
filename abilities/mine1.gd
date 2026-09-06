extends Ability

var base_damage = 20

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 20 damage to target enemy",
		["If Mine's HP is 70 or less, deals 10 more damage and becomes Piercing", Color.CADET_BLUE],
		["If Mine's HP is 40 or less, this skill's cost is reduced to 1 Random energy", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage = base_damage
	var damage_type = DamageType.Type.NORMAL

	if user.health.hp <= 70:
		damage += 10
		damage_type = DamageType.Type.PIERCING

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, damage_type)

func cost():
	var output = super.cost()
	if user and user.health.hp <= 40:
		output = {
			0: 0,
			1: 0,
			2: 0,
			3: 0,
			4: 1
		}
	return output

func extra_usable(user):
	return true

func custom_behavior(context):
	var hp = context['owner'].health.hp
	var mod = 0
	if hp <= 70:
		mod += 20
	if hp <= 40:
		mod += 20
	return behavior_single_target_damage(context, mod)

func target(user, battle):
	var bypassing = user.marked_by("Genius Sniper") != null
	default_hostile_target_function(user, battle, bypassing)
