extends Ability

# Flame of Pride. Gain +1 Sunshine, THEN branch off the post-gain count: 5+ Sunshine -> Invulnerable
# for 1 turn; otherwise a 1-turn Shield of 5 x current stacks.

func describe(user):
	return "Escanor gains 1 stack of Sunshine, and then for 1 turn he gains 5 Shield per stack of Sunshine he has. If he has at least 5 stacks of Sunshine, he instead becomes Invulnerable for 1 turn."

func split_desc():
	return [
		"Escanor gains 1 stack of Sunshine",
		["For 1 turn, gains 5 Shield per stack of Sunshine he has", Color.AQUAMARINE],
		["With 5 or more Sunshine, becomes Invulnerable for 1 turn instead", Color.CADET_BLUE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# gain +1 Sunshine first (heal + cap via the passive helper), then read the post-gain count
	user.moveset.base_abilities[4].gain_stacks(1)
	var stacks = sunshine_stacks(user)
	if stacks >= 5:
		var invuln = Effect.invuln_effect(2)   # "1 turn" == dur 2
		invuln.set_source(self)
		Character.add_allied_effect(context, user, user, invuln)
	else:
		var shield = Effect.shield_effect(5 * stacks, 2)
		shield.stackable = false   # a recast replaces rather than additively merging the shield
		shield.set_source(self)
		Character.add_allied_effect(context, user, user, shield)

func sunshine_stacks(u):
	var e = u.has_effect("Sunshine", EffectType.Type.MARK, u)
	return e.stack_count() if e else 0

func extra_usable(user):
	return true

func custom_behavior(context):
	return behavior_self_panic_button(context, 100)

func target(user, battle):
	default_self_target_function(user, battle)
