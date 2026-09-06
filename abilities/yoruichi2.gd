extends Ability
var base_damage = 25
var per_stack = 10

const GATHER := "Shunko: Gather"

# Shunko: Raijin Senkei. The payoff. It reads the Gather battery at double the rate Gather itself
# does (10 per stack against 5) and does NOT spend it — the stacks are a standing multiplier, so
# every point of setup keeps paying out on every cast.

func describe(user):
	return "Deals 25 Piercing damage to target enemy, increased by 10 for each stack of Shunko: Gather on Yoruichi."

func split_desc():
	return [
		"Deals 25 Piercing damage to target enemy",
		["Deals 10 more damage per stack of Shunko: Gather on Yoruichi", Color.CADET_BLUE],
	]

func gather_stacks(yoruichi) -> int:
	if yoruichi == null or not is_instance_valid(yoruichi):
		return 0
	var marker = yoruichi.has_effect(GATHER, EffectType.Type.MARK, yoruichi)
	return marker.stack_count() if marker else 0

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Read once, before anything can shift it, so every target of a blind-retargeted cast is hit
	# for the same amount.
	var dmg: int = base_damage + per_stack * gather_stacks(user)
	for target in user.targeter.targets:
		Character.resolve_damage(context, target, dmg, DamageType.Type.PIERCING)

func extra_usable(user):
	return true

func custom_behavior(context):
	# Scored by what it would actually hit for, so the bot waits for a fat battery instead of
	# firing it bare.
	return behavior_single_target_damage(context, base_damage + per_stack * gather_stacks(context['owner']))

func target(user, battle):
	default_hostile_target_function(user, battle)
