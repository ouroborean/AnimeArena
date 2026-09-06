extends Ability

# Escape Diary (passive). Owns the shared bookkeeping for BOTH of Minene's stacking marks, mirroring
# gasai5.gd (base_abilities[4]): the "Escape Diary" self-mark and the "Explosives Detonator" enemy-mark.
# minene1 (Grenade), minene2 (Landmines), minene3 (Master of Disguise) and minene6 (Explosives Detonator)
# all reach these helpers through user.moveset.base_abilities[4].<helper>.
#
# Escape Diary self-mark is named "Escape Diary" (source == this passive, whose ability_name is
# "Escape Diary"). The DAMAGE PIPELINE (engine-side, already wired by the caller) reduces a >=20 hit by
# 20% per stack, erases the mark, and calls minene.call_unique("minene","on_escape_diary_consumed",[n])
# with the number of stacks consumed — so this script only PRODUCES the mark; the reduction + the
# "4+ stacks consumed resets Escape Route's cooldown" payoff live in the engine + character/minene.gd.
#
# Explosives Detonator enemy-mark is named "Explosives Detonator" (source == base_abilities[5], whose
# ability_name is "Explosives Detonator"), so a single full_remove_effect_by_name clears both the MARK and
# its TICKING_TRIGGER incrementer at detonation.

const DIARY = "Escape Diary"
const DETONATOR = "Explosives Detonator"

func describe(user):
	return "At the start of Minene's turn, she gains a stack of Escape Diary. When Minene would take 20 or more damage, the hit is reduced by 20% for each Escape Diary stack, consuming all stacks; if 4 or more stacks are consumed, Escape Route's cooldown is reset. When Minene dies, every Explosives Detonator charge on the field detonates."

func split_desc():
	return [
		"At the start of Minene's turn, she gains a stack of Escape Diary",
		["When Minene would take 20 or more damage, it is reduced by 20% per Escape Diary stack, consuming them all; if 4 or more are consumed, Escape Route's cooldown is reset", Color.CADET_BLUE],
		["When Minene dies, all Explosives Detonator charges detonate", Color.ORANGE_RED]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	# Start-of-turn self-stack generator (permanent machinery).
	var start_trigger = Effect.trigger_effect(Trigger.always(diary_turn_tick), EffectType.Type.START_OF_TURN_TRIGGER, -1, "At the start of Minene's turn, she gains a stack of Escape Diary.")
	start_trigger.set_source(self)
	start_trigger.system = true
	Character.add_allied_effect(context, user, user, start_trigger)
	# Detonate-on-death. remove_on_death=false so the death-cleanse doesn't strip it before it fires
	# (check_death_triggers runs BEFORE cleanse_death_effects, so the enemy marks still exist here).
	var death_trigger = Effect.trigger_effect(Trigger.always(on_minene_death), EffectType.Type.ON_DEATH_TRIGGER, -1, "When Minene dies, all Explosives Detonator charges detonate.")
	death_trigger.set_source(self)
	death_trigger.system = true
	death_trigger.remove_on_death = false
	Character.add_allied_effect(context, user, user, death_trigger)

func extra_usable(user):
	return true

func custom_behavior(context):
	var variations = []
	variations.append([0, [user, "PASS", []]])
	return variations

func target(user, battle):
	default_self_target_function(user, battle)

# ---- trigger callbacks ---------------------------------------------------

func diary_turn_tick(context):
	var minene = context['effect'].user
	if minene == null or minene.dead or minene.banished:
		return
	# START_OF_TURN triggers fire for every character each turn; gate to Minene's own team's turn.
	# waiting_for_turn is the player/enemy SIDE split, so derive the acting team from it (gasai5 idiom).
	var acting_team = minene.battle.enemy.team if minene.battle.waiting_for_turn else minene.battle.player.team
	if not minene in acting_team.characters:
		return
	grant_diary_stack(minene, 1)

func detonator_turn_tick(context):
	var eff = context['effect']
	var enemy = eff.target   # from_effect_end sets target = the marked enemy holding this trigger
	var minene = eff.user    # apply_effect set_user = the applier (Minene), not the holder
	if enemy == null or enemy.dead or enemy.banished:
		return
	if minene == null or not is_instance_valid(minene):
		return
	# TICKING_TRIGGER: the ticking engine already fires this only on Minene's own team-turn (it gates by
	# effect.user's team) and never on the turn the trigger was applied, so no manual turn-gating is needed.
	# Stop once the Detonator has consumed the mark.
	if enemy.has_effect(DETONATOR, EffectType.Type.MARK, minene) == null:
		return
	grant_detonator_stack(enemy, 1)

func on_minene_death(context):
	var minene = context['effect'].user
	if minene == null or not is_instance_valid(minene):
		return
	# Minene is already flagged dead here; do NOT bail on that. Attribute the blast to the death trigger
	# (resolve_effect_damage) since there is no used_ability during a death resolution.
	detonate(minene, minene.battle, context['effect'])

# ---- shared helpers ------------------------------------------------------

func grant_diary_stack(minene, n = 1):
	if minene == null or not is_instance_valid(minene):
		return
	var context = QueryContext.from_game_state(minene, minene.battle)
	var existing = minene.has_effect(DIARY, EffectType.Type.MARK, minene)
	if existing:
		existing.stacks += n
		existing.effect_updated.emit(existing)
	else:
		var stack_desc = func (eff):
			return "Escape Diary: " + str(eff.stack_count()) + " stack(s). A 20+ hit is reduced 20% per stack; consuming 4 or more stacks resets Escape Route's cooldown."
		var m = Effect.mark(-1, stack_desc)
		m.set_source(self)
		m.stackable = true
		m.display_stacks = true
		m.stacks = n
		Character.add_allied_effect(context, minene, minene, m)

func grant_detonator_stack(enemy, n = 1):
	var minene = self.user
	if minene == null or not is_instance_valid(minene):
		return
	if enemy == null or enemy.dead or enemy.banished:
		return
	var context = QueryContext.from_game_state(minene, minene.battle)
	var existing = enemy.has_effect(DETONATOR, EffectType.Type.MARK, minene)
	if existing:
		existing.stacks += n
		existing.effect_updated.emit(existing)
	else:
		var stack_desc = func (eff):
			return "Rigged with " + str(eff.stack_count()) + " Explosives Detonator charge(s)."
		var m = Effect.mark(-1, stack_desc)
		# Named after Explosives Detonator (base_abilities[5]) so full_remove_effect_by_name clears it.
		m.set_source(minene.moveset.base_abilities[5])
		m.stackable = true
		m.display_stacks = true
		m.stacks = n
		Character.add_hostile_effect(context, minene, enemy, m)

# Install the once-per-enemy permanent Ticking Trigger that adds another Explosives Detonator charge each
# turn (named "Explosives Detonator" like the mark, so a single full_remove_effect_by_name clears both at
# detonation). Grenade calls this; Landmines does not. GUARD: never install a second one on the same enemy
# — the continuous stack addition does not stack.
func install_detonator_incrementer(enemy):
	var minene = self.user
	if minene == null or not is_instance_valid(minene):
		return
	if enemy == null or enemy.dead or enemy.banished:
		return
	if enemy.has_effect(DETONATOR, EffectType.Type.TICKING_TRIGGER, minene) != null:
		return
	var context = QueryContext.from_game_state(minene, minene.battle)
	var inc = Effect.trigger_effect(Trigger.always(detonator_turn_tick), EffectType.Type.TICKING_TRIGGER, -1, "This enemy gains a stack of Explosives Detonator each turn.")
	inc.set_source(minene.moveset.base_abilities[5])
	# Intentionally NOT system: players should see that the target is accruing a stack each turn. It shares
	# the name "Explosives Detonator" with the mark, so it clusters into that one tooltip panel, and it
	# surfaces as a ticking step in the end-turn reorder preview.
	Character.add_hostile_effect(context, minene, enemy, inc)

# Shared detonation used by both the active Explosives Detonator cast (eff == null -> resolve_damage) and
# the on-death trigger (eff == the ON_DEATH_TRIGGER effect -> resolve_effect_damage).
func detonate(minene, battle, eff = null):
	if minene == null or not is_instance_valid(minene) or battle == null:
		return
	var context = QueryContext.from_game_state(minene, battle)
	for enemy in battle.all_characters():
		if enemy in minene.team.characters:
			continue
		if enemy.dead or enemy.banished:
			continue
		var mark = enemy.has_effect(DETONATOR, EffectType.Type.MARK, minene)
		if mark:
			var dmg = 10 * mark.stack_count()
			if eff == null:
				Character.resolve_damage(context, enemy, dmg, DamageType.Type.NORMAL)
			else:
				Character.resolve_effect_damage(context, eff, enemy, dmg, DamageType.Type.NORMAL)
		# Clears BOTH the mark AND the Ticking Trigger incrementer (both named "Explosives Detonator") from
		# every enemy that carries either — so the continuous stack addition stops even if the mark alone was
		# stripped off. no-ops on an enemy that has neither.
		enemy.effects.full_remove_effect_by_name(DETONATOR, minene)
