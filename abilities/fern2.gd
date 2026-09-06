extends Ability

const MANA := "Mana Control"

# Mana Control. A stance, not a buff: it costs energy to raise and stays up until Fern spends
# another action lowering it. It changes nothing by itself — Zoltraak Beam, Zoltraak Blasts and
# Talented Child each read it and swap to their enhanced form.
#
# The toggle is the ryuko2 "Decapitation Mode" idiom: a permanent, non-cleansable self MARK that
# this ability adds when absent and removes when present. Non-cleansable because an enemy strip
# would otherwise silently downgrade three skills at once with no way for Fern to tell — and
# because she can always turn it off herself, a cleanse would be pure profit for the enemy.

func describe(user):
	return "Zoltraak Beam, Zoltraak Blasts and Talented Child use their enhanced effects. Ends when Mana Control is used again."

func split_desc():
	return [
		["Enhances Zoltraak Beam, Zoltraak Blasts, and Talented Child", Color.CADET_BLUE],
		["Lasts until this skill is used again", Color.DIM_GRAY],
	]

# Self-contained on purpose: reaching into base_abilities[1] would crash the moment a copy or steal
# mechanic ran one of Fern's skills from another character.
func mana_control_active(fern) -> bool:
	return fern != null and is_instance_valid(fern) and fern.marked_by(MANA, fern) != null

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if mana_control_active(user):
		user.effects.full_remove_effect_by_name(MANA, user)
		return
	var mark = Effect.mark(-1, "Zoltraak Beam, Zoltraak Blasts and Talented Child are enhanced. Fern can use Mana Control again to end this.")
	mark.cleansable = false
	apply_allied(context, user, mark)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	# Raising the stance is worth a turn only when there is energy for it to scale off; lowering it
	# is almost never right, so an active stance scores a flat PASS.
	var fern = context['owner']
	if mana_control_active(fern):
		variations.append([0, [user, "PASS", []]])
		return variations
	var bank: int = leftover_energy(fern)
	variations.append([30 + bank * 10, [user, self, [user]]])
	return variations

# Shared with fern1/fern3 — see fern1.leftover_energy for the full derivation.
func leftover_energy(fern) -> int:
	if fern == null or fern.team == null or fern.team.energy == null:
		return 0
	var ep = fern.team.energy
	var total: int = 0
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		total += int(ep.pool.get(color, 0))
		total -= maxi(int(ep.promised_pool.get(color, 0)), 0)
	total -= maxi(int(ep.promised_pool.get(Energy.Type.RANDOM, 0)), 0)
	return maxi(total, 0)

func target(user, battle):
	default_self_target_function(user, battle)
