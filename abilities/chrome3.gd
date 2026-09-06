extends Ability

func describe(user):
	return "Chrome heals 15 HP and allows Rokudo control of her body, Empowering her other skills for her next 3 turns. If Chrome is at or below 40 HP, this skill has no cost."

func split_desc():
	return [
		"Chrome heals 15 HP and becomes Empowered for 3 turns",
		"Empowerment enhances Chrome's other skills",
		["If Chrome is at or below 40 HP, this skill has no cost", Color.DIM_GRAY],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	Character.resolve_healing(context, user, 15)

	var mark = Effect.mark(7, "Rokudo Mukuro has taken control. Chrome's skills are Empowered.")
	mark.set_source(self)
	Character.add_allied_effect(context, user, user, mark)

	var portrait = Effect.portrait_change_effect(0, 7)
	portrait.set_source(self)
	Character.add_allied_effect(context, user, user, portrait)
	
	var target_change = Effect.target_change_effect(TargetType.Type.ALL, 7, ["Illusion: Flame Pillar"])
	target_change.set_source(self)
	Character.add_allied_effect(context, user, user, target_change)

func cost():
	var output = super.cost()
	if user and user.health.hp <= 40:
		output = {
			0: 0,
			1: 0,
			2: 0,
			3: 0,
			4: 0
		}
	return output

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var mod = 80
	if context['owner'].health.hp <= 40:
		mod += 40
	variations += behavior_self_panic_button(context, mod)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
