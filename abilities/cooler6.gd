extends Ability

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	return "Whenever Death Chaser damages a Stunned enemy or drops a target to below 50 HP, or Nova Chariot is successfully triggered, Cooler enters his Final Form for 1 turn. While in this Form, Death Chaser costs 1 less Random energy, Supernova deals its damage instantly, and Cooler cannot be stunned."

func split_desc():
	return [
		"Triggers Final Form when:",
		"   - Death Chaser damages a Stunned enemy",
		"   - Death Chaser drops a target below 50 HP",
		"   - Nova Chariot is successfully triggered",
		["Final Form (1 turn): Death Chaser -1 Random cost, Supernova deals damage instantly, immune to Stun", Color.AQUAMARINE]
	]

func execute(user, battle):
	# Passive with no startup state. The three Final Form triggers each call
	# enter_final_form directly from the abilities that observe their own
	# success conditions (cooler1 for the Death Chaser triggers, cooler4 for
	# the Nova Chariot trigger). Doing it that way lets each caller capture
	# its own pre-state (e.g. pre-damage HP, pre-damage stun status) — a
	# HARMFUL_USE_TRIGGER on Cooler here couldn't see those because it would
	# fire after damage resolution.
	pass

# Called by cooler1.execute when a Death Chaser hit meets the Final Form
# pre-conditions, and by cooler4.nova_chariot_trigger when Nova Chariot's
# reactive trigger lands. Idempotent — re-applying refreshes the duration
# back to the full 1-turn window via refresh=true on each effect.
func enter_final_form(context, cooler):
	var mark_desc = func (eff):
		return "Supernova deals its damage instantly."
	var mark = Effect.mark(3, mark_desc)
	mark.set_source(self)
	mark.refresh = true
	Character.add_allied_effect(context, cooler, cooler, mark, true)

	# Death Chaser cost reduction. ability_targets=["Death Chaser"] scopes the
	# discount; element=RANDOM zeroes the 1-Random portion of Death Chaser's
	# cost while leaving the 1-Green cost intact.
	var cost = Effect.cost_mod_effect(-1, 3, Energy.Type.RANDOM, ["Death Chaser"])
	cost.set_source(self)
	cost.refresh = true
	Character.add_allied_effect(context, cooler, cooler, cost, true)

	# Stun immunity. ignore_effect_effect lets Cooler shrug off any incoming
	# STUN effects for the duration.
	var stun_immune = Effect.ignore_effect_effect(3, EffectType.Type.STUN)
	stun_immune.set_source(self)
	stun_immune.refresh = true
	stun_immune.cleansable = false
	Character.add_allied_effect(context, cooler, cooler, stun_immune, true)
	
	var portrait_swap = Effect.portrait_change_effect(0, 3)
	portrait_swap.set_source(self)
	portrait_swap.refresh = true
	Character.add_allied_effect(context, cooler, cooler, portrait_swap, true)
	
	

func extra_usable(user):
	return true

func target(user, battle):
	pass
