extends Ability

const SWAP_IN_NAME := "Fickle Flash"

# Black Cat Warrior Princess. Three turns of Shunko at full output: the punish hits harder, it now
# Shatters, and this slot becomes Fickle Flash.
#
# The ABILITY_SWAP is the ONLY state this ability creates. Everything that asks "is Black Cat up?"
# keys off Fickle Flash being in the active list (yoruichi1.black_cat_active), so the damage bonus,
# the Shatter rider and Fickle Flash's availability cannot desync from each other. gasai2/gasai5's
# Breakdown is the shipped precedent for exactly this.
#
# Duration 7 = "3 turns" for a swap (the 2N+1 rule), verified against gasai2 at N=3.

func describe(user):
	return "For the next 3 turns, Shunko: Gather's damage is increased by 10, and any enemy that triggers it will be Shattered for 1 turn. During this time, this skill is replaced by Fickle Flash."

func split_desc():
	return [
		["For 3 turns, Shunko: Gather deals 10 more damage", Color.CADET_BLUE],
		["Enemies that trigger Shunko: Gather are Shattered for 1 turn", Color.ORANGE_RED],
		["Swaps to Fickle Flash while active", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# set_source is load-bearing, not decoration: apply_effect silently drops and frees any
	# ABILITY_SWAP whose source is not in the applier's base_abilities.
	var swap = Effect.ability_swap_effect(4, 2, user, 7)
	swap.set_source(self)
	Character.add_allied_effect(context, user, user, swap)
	# The swap's own tooltip only says which skill replaced which. The empowerment — the whole
	# reason to press this — is computed live from black_cat_active() and had NOTHING on screen
	# representing it, so neither player could see that Gather had gotten stronger. This mark is
	# pure display; the swap remains the single source of truth (see the header note), and it is
	# uncleansable to match, so it can never outlive or predecease what it describes.
	var banner = Effect.mark(7, "Shunko: Gather deals 10 more damage and Shatters its target for 1 turn.")
	banner.set_source(self)   # add_allied_effect does not assign one; without it the effect is nameless
	banner.cleansable = false
	Character.add_allied_effect(context, user, user, banner)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	var yoruichi = context['owner']
	# Worth very little with no battery to protect — on its own it neither damages nor defends.
	var marker = yoruichi.has_effect("Shunko: Gather", EffectType.Type.MARK, yoruichi)
	var stacks: int = marker.stack_count() if marker else 0
	if stacks == 0:
		variations.append([0, [user, "PASS", []]])
		return variations
	variations.append([40 + stacks * 10, [user, self, [user]]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
