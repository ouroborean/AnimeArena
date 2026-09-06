extends Ability

var base_damage = 15

func describe(user):
	return "Deals 15 damage to target enemy."

func split_desc():
	return [
		"Deals 15 damage to target enemy",
		["If Amidamaru Over Soul is active, damage is doubled", Color.CADET_BLUE],
		["If Spirit of Sword is active, the target is stunned for 1 turn", Color.CADET_BLUE],
		["If White Swan Over Soul is active, deals 20 damage and steals up to 20 HP", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var amidamaru = user.has_effect("Amidamaru Over Soul", EffectType.Type.MARK, user)
	var white_swan = user.has_effect("White Swan Over Soul", EffectType.Type.MARK, user)
	var spirit = user.has_effect("Spirit of Sword", EffectType.Type.MARK, user)

	var damage = base_damage
	if white_swan:
		damage = 20
	elif amidamaru:
		damage = 30

	for target in user.targeter.targets:
		var before_hp = target.health.hp
		Character.resolve_damage(context, target, damage, DamageType.Type.NORMAL)
		if white_swan:
			var landed = max(0, before_hp - target.health.hp)
			var steal = min(20, landed)
			if steal > 0:
				Character.resolve_healing(context, user, steal)
		if spirit and not target.dead:
			var stun = Effect.stun_effect(2)
			stun.set_source(self)
			Character.add_hostile_effect(context, user, target, stun)

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 30)

func target(user, battle):
	default_hostile_target_function(user, battle)
