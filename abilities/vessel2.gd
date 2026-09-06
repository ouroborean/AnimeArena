extends Ability

# Bandage — heals one ally 10 HP for 2 turns (immediate tick + heal-over-time), mirroring marco5.
# Cost/cooldown/classes/target_type come from abilities_data.json via Ability.from_database.

var base_healing = 10

func describe(user):
	return ""

func split_desc():
	return [
		"Heals target ally 10 HP for 2 turns",
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	for target in user.targeter.targets:
		Character.resolve_healing(context, target, base_healing)
		var eff = Effect.healing_effect(base_healing, 3)   # 3 == 2 turns (durations tick every player turn)
		eff.set_source(self)
		Character.add_allied_effect(context, user, target, eff)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations += behavior_single_target_heal(context, base_healing)
	return variations

func target(user, battle):
	default_allied_target_function(user, battle)
