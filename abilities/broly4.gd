extends Ability

var heal_per_stack = 5

func describe(user):
	return "Broly becomes Invulnerable for 1 turn and heals 10 HP for each stack of Legendary Super Saiyan on him."

func split_desc():
	return [
		"Broly becomes Invulnerable for 1 turn",
		["Heals 5 HP for each stack of Legendary Super Saiyan", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var shell = Effect.invuln_effect(2)
	shell.set_source(self)
	Character.add_allied_effect(context, user, user, shell)

	var lss = user.effects.has_effect("Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, user)
	if lss:
		Character.resolve_healing(context, user, heal_per_stack * lss.stack_count())

func extra_usable(user):
	return true

func custom_behavior(context):
	# Weight follows the heal nerf: with the 4-stack cap the payout ceiling is a
	# hard 20 HP, down from uncapped, so the policy should stop over-valuing it.
	return behavior_self_panic_button(context, 15)

func target(user, battle):
	default_self_target_function(user, battle)
