extends Ability

func describe(user):
	return "For the rest of the game, Denji can use his other skills. This skill permanently becomes Ripcord Pull."

func split_desc():
	return [
		"Unlocks Denji's other skills for the rest of the game",
		["This skill permanently becomes Ripcord Pull", Color.AQUAMARINE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Permanent "transformed" marker — the gate key for Denji's other skills. Identity state, so it is
	# invisible and uncleansable (a cleanse must not lock his kit back up).
	var mark = Effect.mark(-1, "Denji has transformed; his other skills are unlocked.")
	mark.set_source(self)
	mark.invisible = true
	mark.cleansable = false
	Character.add_allied_effect(context, user, user, mark)
	# Permanently swap this display slot (2 — Devil Transformation is Denji's S3) for Ripcord Pull
	# (hidden base_abilities index 5).
	var swap = Effect.ability_swap_effect(5, 2, user, -1)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([300, [user, self, [user]]])   # transform ASAP — everything else is gated behind it (self-target, so the target list is [user] or the bot skips it)
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
