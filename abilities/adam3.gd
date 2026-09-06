extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

var base_damage = 30
var blinded_damage = 45

func describe(user):
	return "Deals 30 Piercing damage to target enemy, increased to 45 if Adam is Blinded. If this skill kills the enemy, all Blind effects are removed from Adam."

func split_desc():
	return [
		"Deals 30 Piercing damage to target enemy",
		"Increased to 45 while Adam is Blinded",
		["If this skill kills the enemy, removes all Blind from Adam", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var damage = base_damage
	if len(user.effects.get_effects_by_type(EffectType.Type.BLIND)) > 0 and not user.shrug_off_type(EffectType.Type.BLIND):
		damage = blinded_damage
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, damage, DamageType.Type.PIERCING)
		if target.dead:
			user.effects.full_remove_effect_by_type(EffectType.Type.BLIND)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_damage(context, 45, 1.2, false)
	return variations

func bot_damage_hint() -> float:
	return float(blinded_damage)

func target(user, battle):
	default_hostile_target_function(user, battle)
