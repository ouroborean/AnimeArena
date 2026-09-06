extends Ability

# ============================================================================
# UNREGISTERED / DISABLED — this ability is NOT part of Death's moveset.
# Death's skill count is 4 (death1-death4); there is no "death5" row in
# abilities_data.json and no entry in the client ability data, so this script
# is never loaded and anchored_gate() is never called. death1/2/3 no longer
# pass a mark_req to default_hostile_target_function.
# Kept on disk verbatim in case the passive is reworked and re-enabled later.
# To re-enable: bump character_ability_counts.json "death" back to 5, restore
# the "death5" row in abilities_data.json, regenerate the client ability JSON,
# and re-add the anchored_gate(user) mark_req argument to death1/2/3's target().
# ============================================================================

# Anchored Soul (PASSIVE, index 4). While at least one of Death's allies is alive, Death's Harmful skills
# can only target enemies that used a Harmful skill on their LAST turn; with no living ally, the
# restriction lifts. Mechanism (adam5 pattern):
#   - At battle start, plant a permanent HARMFUL_USE_TRIGGER on every enemy.
#   - When an enemy uses a Harmful skill, that trigger brands them with a dur-2 "Anchored Soul" MARK
#     (dur 2 survives through Death's very next turn then expires, so the enemy must re-attack each turn
#     to stay branded — i.e. "used a Harmful skill last turn").
#   - anchored_gate(user) returns the brand name as a mark_req (or null when no ally lives); each of
#     Death's harmful abilities' target() passes it to default_hostile_target_function, so only branded
#     enemies are selectable. No shared-engine edit; the gate lives entirely in Death's files.

const BRAND = "Anchored Soul"

func describe(user):
	return "While at least one of Death's allies is alive, Death's Harmful skills can only target enemies that used a Harmful skill on their last turn. With no living allies, this restriction is lifted."

func split_desc():
	return [
		["While an ally lives, Death can only target enemies who used a Harmful skill last turn", Color.CADET_BLUE],
		"With no living allies, Death may target any enemy"
	]

func execute(user, battle):
	# Runs once at battle start via startup_passives.
	var context = QueryContext.from_game_state(user, battle)
	for enemy in context.enemy_team.characters:
		var trig = Effect.trigger_effect(Trigger.always(enemy_used_harmful), EffectType.Type.HARMFUL_USE_TRIGGER, -1, "When this enemy uses a Harmful skill, Death may target them next turn.")
		trig.set_source(self)
		trig.system = true
		trig.invisible = true
		# Survive Death's own death: this trigger's user is Death, so cleanse_death_effects would otherwise
		# strip it off every enemy when Death dies (it keeps user==Death effects unless system AND
		# remove_on_death==false), and execute() never re-runs on revive — permanently disabling branding.
		trig.remove_on_death = false
		Character.add_hostile_effect(context, user, enemy, trig, true)

# HARMFUL_USE_TRIGGER callback. from_effect_end sets .user = the applier (Death) and .target = the holder
# (the enemy who just used a Harmful skill).
func enemy_used_harmful(context):
	var death = context['effect'].user
	var enemy = context['effect'].target
	if death == null or not is_instance_valid(death) or death.battle == null:
		return
	if enemy == null or enemy.dead or enemy.banished:
		return
	var ctx = QueryContext.from_game_state(death, death.battle)
	var mark = Effect.mark(2, "Used a Harmful skill last turn - Death may target them.")
	mark.set_source(self)     # effect_name() == BRAND
	mark.refresh = true       # re-attacking refreshes the window instead of stacking a duplicate
	mark.id = ctx.id
	# Apply directly, NOT via add_hostile_effect: the brand is Death's internal targeting bookkeeping, not a
	# gameplay debuff, so it must NOT route through the silence/invuln/shrug-off chokepoint — a SILENCED
	# Death must still brand his aggressors, or silence would rob him of harmful targeting entirely.
	# apply_effect sets user == Death, so the mark_req lookup (has_effect(BRAND, MARK, Death)) still matches.
	death.apply_effect(mark, enemy)

# Returns the mark_req for Death's harmful target() calls: the brand name while a living ally remains,
# else null (unrestricted). Called as user.moveset.base_abilities[4].anchored_gate(user) from death1/2/3.
func anchored_gate(user):
	for ally in user.team.characters:
		if ally != user and not (ally.dead or ally.banished):
			return BRAND
	return null

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)
