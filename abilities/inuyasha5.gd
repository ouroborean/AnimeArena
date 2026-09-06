extends Ability

# The three skills the cycle actually swings: their base damage is rewritten in inuyasha1/2/3
# (20/10/30 -> 30/15/45 awakened, -> 10/5/15 waned) and their cost is shifted by the COST_MOD below.
# Single source of truth so the cost effect's targets and the mark's tooltip can't drift apart.
const CYCLE_SKILLS = ["Wind Scar", "Iron Reaver Soul Stealer", "Blades of Blood"]

# "A, B and C" - the same phrasing Effect.cost_mod_effect builds for its own tooltip.
func cycle_skill_text():
	return ", ".join(CYCLE_SKILLS.slice(0, CYCLE_SKILLS.size() - 1)) + " and " + CYCLE_SKILLS[-1]

#Check the export variables in the Inspector for the ability image, cooldown, cost dictionary, setting ability classes,
#setting the ability's name, and choosing the targeting type.

func describe(user):
	#This is part of what is used to generate the information panel for an ability, so make sure it's accurate
	return ""

func split_desc():
	return [
		"Every 2 turns, Hanyo Cycle awakens or wanes for 2 turns",
		["While awakened, Inuyasha's Harmful skills deal 50% more damage and cost 1 more Random energy", Color.CADET_BLUE],
		["While waning, Inuyasha's Harmful skills deal half damage and cost 1 less Red energy", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var ticking = Effect.trigger_effect(Trigger.always(tick_trigger), EffectType.Type.TICKING_TRIGGER, -1, "When this counter reaches 0, Hanyo Cycle will awaken or wane.")
	ticking.mag = 2
	ticking.display_mag = true
	ticking.set_source(self)
	Character.add_allied_effect(context, user, user, ticking)
	
	var dmg_trigger = Effect.trigger_effect(Trigger.always(damage_trigger), EffectType.Type.DAMAGE_RECEIVE_TRIGGER, -1, "Blades of Blood will re-trigger for each time Inuyasha takes new damage, up to 3 extra times.")
	dmg_trigger.set_source(user.moveset.base_abilities[1])
	dmg_trigger.display_mag = true
	Character.add_allied_effect(context, user, user, dmg_trigger)

func damage_trigger(context):
	var trigger = user.has_effect("Blades of Blood", EffectType.Type.DAMAGE_RECEIVE_TRIGGER)
	trigger.mag += 1
	if trigger.mag >= 4:
		trigger.mag = 3

func tick_trigger(context):
	var tick = user.has_effect("Hanyo Cycle", EffectType.Type.TICKING_TRIGGER)
	tick.mag -= 1
	if tick.mag == 0:
		var roll = user.battle.roll(1, 2)
		tick.display_mag = false
		tick.description = func (eff): return "The cycle will begin again once Hanyo Cycle returns to normal."
		tick.mag = 4
		match roll:
			1:
				var mark = Effect.mark(5, "Hanyo Cycle has awakened. " + cycle_skill_text() + " deal 50% more damage.")
				mark.set_source(self)
				mark.mag = 1
				var cost_mod = Effect.cost_mod_effect(1, 5, Energy.Type.RANDOM, CYCLE_SKILLS)
				cost_mod.set_source(self)
				var portrait_swap = Effect.portrait_change_effect(1, 5)
				portrait_swap.set_source(self)
				Character.add_allied_effect(context, user, user, mark)
				Character.add_allied_effect(context, user, user, cost_mod)
				Character.add_allied_effect(context, user, user, portrait_swap)
				
			2:
				var mark = Effect.mark(5, "Hanyo Cycle has waned. " + cycle_skill_text() + " deal half damage.")
				mark.set_source(self)
				mark.mag = 2
				var cost_mod = Effect.cost_mod_effect(-1, 5, Energy.Type.RED, CYCLE_SKILLS)
				cost_mod.set_source(self)
				var portrait_swap = Effect.portrait_change_effect(0, 5)
				portrait_swap.set_source(self)
				Character.add_allied_effect(context, user, user, mark)
				Character.add_allied_effect(context, user, user, cost_mod)
				Character.add_allied_effect(context, user, user, portrait_swap)
	elif tick.mag == 3:
		tick.display_mag = true
		tick.description = func (eff): return "When this counter reaches 0, Hanyo Cycle will awaken or wane."

func extra_usable(user):
	#Extra state requirements (Like something being marked) go here.
	#Use naughty references like user.battle.all_characters() or user.team.characters to reference
	#the current match
	return true
	
func custom_behavior(context):
	var variations = []
	
	variations.append([0, [user, "PASS", []]])
	
	return variations
	
func target(user, battle):
	#There are 3 default targeting functions, but if there are unique requirements, just put them here
	default_hostile_target_function(user, battle)
	default_allied_target_function(user, battle)
	default_self_target_function(user, battle)
