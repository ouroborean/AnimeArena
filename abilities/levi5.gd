extends Ability

# Relentless Captain (passive) — installed once at battle start via startup_passives (this ability
# carries the "Passive" class, so character_component.startup_passives calls its execute()). It plants
# a permanent, invisible MISSION_TRIGGER_ON_KILL on Levi: check_kill_triggers fires it on the KILLER
# every time Levi lands a kill (from any skill OR his ODM Gear Assault DoT — the trigger callback
# never sets `triggered`, so it is per-kill, not once-per-turn). Each kill applies a permanent +5
# DAMAGE_MOD that is stackable/stack_mag, so repeated kills merge into one growing "+5 per kill"
# buff (mirrors adam5's permanent damage stack).

func describe(user):
	return ""

func split_desc():
	return [
		["Each time Levi kills an enemy, he permanently deals 5 more damage (stacks)", Color.CADET_BLUE],
	]

func execute(user, battle):
	# Runs once via startup_passives at battle start.
	var context = QueryContext.from_game_state(user, battle)
	var kill_trigger = Effect.trigger_effect(Trigger.always(relentless_kill), EffectType.Type.MISSION_TRIGGER_ON_KILL, -1, "When Levi kills an enemy, he permanently deals 5 more damage.")
	kill_trigger.set_source(self)
	kill_trigger.invisible = true
	kill_trigger.system = true
	Character.add_allied_effect(context, user, user, kill_trigger)

func relentless_kill(context):
	# context comes from QueryContext.from_trigger_source: context['effect'] is this kill trigger,
	# whose user is Levi (we added it as an allied effect to him).
	var levi = context['effect'].user
	if levi == null or levi.dead or levi.banished:
		return
	var ctx = QueryContext.from_game_state(levi, levi.battle)
	var boost = Effect.damage_mod_effect(5, -1)
	boost.stackable = true
	boost.stack_mag = true
	boost.display_stacks = true
	boost.set_source(self)
	Character.add_allied_effect(ctx, levi, levi, boost)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
