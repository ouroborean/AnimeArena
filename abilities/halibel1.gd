extends Ability

var base_damage = 25
var sacrifice_bonus = 5

func describe(user):
	var ally_protected = _any_ally_has_sacrifice(user)
	var bonus = sacrifice_bonus if ally_protected else 0
	return "Halibel fires a wave of blue Reiatsu, dealing " + str(base_damage + bonus) + " Energy damage to target enemy."

func split_desc():
	return [
		"Deals 25 Energy damage to target enemy.",
		["Deals 5 additional damage if any ally is protected by Aspect of Sacrifice.", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var bonus = sacrifice_bonus if _any_ally_has_sacrifice(user) else 0
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, base_damage + bonus, DamageType.Type.ENERGY)

func _any_ally_has_sacrifice(user):
	for ally in user.team.characters:
		if ally.dead or ally.banished:
			continue
		if ally.has_effect("Aspect of Sacrifice", EffectType.Type.DAMAGE_REDIRECT, user):
			return true
	return false

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_single_target_damage(context, 0, 1.0)

func target(user, battle):
	default_hostile_target_function(user, battle)
