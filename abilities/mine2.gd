extends Ability

var base_damage = 25

func describe(user):
	return ""

func split_desc():
	return [
		"Deals 25 Piercing damage to all enemies",
		["If Mine's HP is 60 or less, stuns all enemies' non-Strategic skills for 1 turn", Color.CADET_BLUE],
		["If Mine's HP is 30 or less, deals 15 more damage", Color.DIM_GRAY]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage = base_damage

	if user.health.hp <= 30:
		damage += 15

	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
		if user.health.hp <= 60:
			var stun = Effect.stun_effect(2, [], ["Strategic"])
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	var hp = context['owner'].health.hp
	var mod = 30
	if hp <= 60:
		mod += 40
	if hp <= 30:
		mod += 30
	return behavior_hostile_aoe_damage(context, mod)

func target(user, battle):
	var bypassing = user.marked_by("Genius Sniper") != null
	default_hostile_target_function(user, battle, bypassing)
