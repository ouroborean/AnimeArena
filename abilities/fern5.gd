extends Ability
var per_grant = 3

const MANA := "Mana Control"
const COUNTER := "Talented Child"

# Talented Child. Fern's economy: every fourth point of colour her team spends comes back as a
# fresh one. Unenhanced it returns Red or Green — colours nothing in her own kit uses — so it is a
# gift to her teammates; under Mana Control it returns White or Blue instead and refills her own
# skills, which is what lets the Mana Control turns chain.
#
# WHAT COUNTS. Only the SPECIFIC-colour pips of a skill's cost — Green, Blue, White, Red. A Random
# pip is paid out of the same pool, so the team's actual drain (and BattleManager's
# energy_spent_event, which reports exactly that drain) cannot tell the two apart: a 1 Blue + 1
# Random skill drains two colours and would wrongly count as two. So the hook is a per-skill
# ACTION_USE_TRIGGER on each teammate instead, reading the resolved cost() and summing keys 0-3
# while ignoring RANDOM. That is also why this no longer depends on the human-only turn-package
# signal.
#
# The running remainder lives in a permanent self MARK's mag rather than a member var, so it
# survives a reconnect resync the way an Ability instance would not.

func describe(user):
	return "Every 3 colored energy Fern spends, she generates 1 Red or Green energy at random. If Mana Control is active, she instead generates 1 White or Blue energy at random."

func split_desc():
	return [
		["Every 3 colored energy Fern's team spends, she generates 1 Red or Green energy at random", Color.CADET_BLUE],
		["If Mana Control is active, she generates 1 White or Blue energy at random instead", Color.CADET_BLUE],
	]

func mana_control_active(fern) -> bool:
	return fern != null and is_instance_valid(fern) and fern.marked_by(MANA, fern) != null

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# The remainder carrier. Invisible to the opponent but visible to Fern's owner, because knowing
	# how close the next energy is genuinely informs the turn.
	if user.has_effect(COUNTER, EffectType.Type.MARK, user) == null:
		var counter = Effect.mark(-1, counter_desc)
		counter.name_override = COUNTER
		counter.mag = 0
		counter.invisible = true
		counter.cleansable = false
		apply_allied(context, user, counter)
	_plant_watchers(context, user)


func _has_watcher(character) -> bool:
	for eff in character.effects.get_effects_by_type(EffectType.Type.ACTION_USE_TRIGGER):
		if eff.source == self:
			return true
	return false


## One watcher per team member, including Fern. check_ability_use_triggers walks the ACTING
## character's own effect list, so a per-character copy is the only way to see every skill her side
## uses. Idempotent, so it is safe to call again to repair a missing one.
func _plant_watchers(context, fern) -> void:
	for ally in fern.team.characters:
		if _has_watcher(ally):
			continue
		var watcher = Effect.trigger_effect(Trigger.always(on_skill_used), EffectType.Type.ACTION_USE_TRIGGER, -1, "")
		watcher.set_source(self)
		watcher.invisible = true
		# system AND remove_on_death=false: the death cleanse keeps a dying character's own effects
		# only when both hold, and startup_passives never re-runs on revive.
		watcher.system = true
		watcher.remove_on_death = false
		Character.add_allied_effect(context, fern, ally, watcher)


## Fires when any of Fern's team uses a skill. Counts only the specific-colour portion of its cost.
func on_skill_used(context):
	var eff = context['effect']
	var fern = eff.user
	var skill = context['source']
	if fern == null or not is_instance_valid(fern) or fern.dead or fern.banished:
		return
	if fern.battle == null or not is_instance_valid(fern.battle):
		return
	if not (skill is Ability):
		return
	var spent: int = 0
	var skill_cost = skill.cost()
	for color in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		spent += int(skill_cost.get(color, 0))
	_credit(fern, spent)

func counter_desc(eff):
	var left: int = per_grant - int(eff.mag)
	return "Fern generates an energy after " + str(left) + " more colored energy is spent."

## Add `spent` colour to the running remainder and pay out every full 4.
func _credit(fern, spent: int) -> void:
	if spent <= 0:
		return
	var counter = fern.has_effect(COUNTER, EffectType.Type.MARK, fern)
	if counter == null:
		# The counter is death-cleansed with everything else Fern cast, and startup_passives never
		# re-runs on revive. Rebuild it rather than silently retiring the passive for the match.
		# (It stays non-system so her owner can still see the progress.)
		execute(fern, fern.battle)
		counter = fern.has_effect(COUNTER, EffectType.Type.MARK, fern)
		if counter == null:
			return
	var total: int = int(counter.mag) + spent
	var grants: int = int(total / per_grant)
	counter.mag = total % per_grant
	counter.effect_updated.emit(counter)
	for i in range(grants):
		# battle.roll is the seeded RNG. Enhanced returns the colours Fern's own kit spends
		# (White/Blue); unenhanced returns the two it does not.
		var pair = [Energy.Type.WHITE, Energy.Type.BLUE] if mana_control_active(fern) else [Energy.Type.RED, Energy.Type.GREEN]
		fern.gain_bonus_energy(pair[fern.battle.roll(0, 1, "Talented Child energy")])

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
