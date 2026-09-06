extends Ability

# Yukiteru Diary (passive). Owns the shared Yukiteru Diary bookkeeping; gasai1 (Axe Crazy) and
# gasai6 (Mow Down) call total_diary_stacks()/consume_all_diary() on this instance via
# user.moveset.base_abilities[4], mirroring adam2.gd -> base_abilities[4].

const DIARY = "Yukiteru Diary"
const MAX_DIARY_STACKS = 3

# Characters whose effect_removed signal we've hooked for the Breakdown restore (armed lazily the first
# time each character is granted a stack). Persists on this single passive instance for the battle.
var _diary_watched = []

# True only while Mow Down is actively consuming stacks (consume_all_diary). Breakdown must NOT restore
# stacks that Mow Down consumes — it should only stop them from timing out — so the restore watch
# checks this flag and bails during a consume. STATIC so it gates EVERY Yuno passive's restore watch:
# a shared holder's effect_removed fires all connected watches, and in a two-Yuno mirror match the
# other Yuno's watch (a different instance) must also see the consume-in-progress. Set/reset within one
# synchronous erase loop (no await), so it can never be left true or interleave across battles.
static var _consuming_diary = false

func describe(user):
	return "At the start of Yuno's turn, she and a random ally are marked with 1 stack of Yukiteru Diary, to a maximum of 3 stacks per character. Each time she uses a skill, 1 stack is removed from her. Any time a marked ally receives a Harmful skill, they lose 1 stack and the attacking enemy is marked for 1 turn."

func split_desc():
	return [
		"At the start of Yuno's turn, she and a random ally gain 1 stack of Yukiteru Diary",
		["Yukiteru Diary stacks up to 3 times on a character", Color.CADET_BLUE],
		"Each skill Yuno uses removes 1 stack of Yukiteru Diary from her",
		["When a marked ally is hit by a Harmful skill, they lose 1 stack and the attacker is marked with Yukiteru Diary for 1 turn", Color.CADET_BLUE]
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	var start_trigger = Effect.trigger_effect(Trigger.always(turn_start_marks), EffectType.Type.START_OF_TURN_TRIGGER, -1, "At the start of Yuno's turn, she and a random ally gain a stack of Yukiteru Diary.")
	start_trigger.set_source(self)
	start_trigger.system = true
	Character.add_allied_effect(context, user, user, start_trigger)
	var use_trigger = Effect.trigger_effect(Trigger.always(on_yuno_act), EffectType.Type.ACTION_USE_TRIGGER, -1, "Each skill Yuno uses removes a stack of Yukiteru Diary from her.")
	use_trigger.set_source(self)
	use_trigger.system = true
	Character.add_allied_effect(context, user, user, use_trigger)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)

# ---- trigger callbacks ---------------------------------------------------

func turn_start_marks(context):
	var yuno = context['effect'].user
	if yuno.dead or yuno.banished:
		return
	# START_OF_TURN triggers fire for every character on BOTH sides each turn. Gate to Yuno's own
	# team's turn ("at the start of Yuno's turn"). waiting_for_turn is the player/enemy SIDE split,
	# so derive the acting team from it (mavis5.gd idiom) — correct whether Yuno is player 1 or 2.
	var acting_team = yuno.battle.enemy.team if yuno.battle.waiting_for_turn else yuno.battle.player.team
	if not yuno in acting_team.characters:
		return
	grant_diary_stack(yuno, 1)
	var candidates = []
	for ally in yuno.team.characters:
		if ally == yuno:
			continue
		if not (ally.dead or ally.banished):
			candidates.append(ally)
	if not candidates.is_empty():
		var pick = candidates[yuno.battle.roll(0, candidates.size() - 1)]
		grant_diary_stack(pick, 1)

func on_yuno_act(context):
	var yuno = context['effect'].user
	if breakdown_active(yuno):
		return   # Breakdown: Yukiteru Diary cannot be removed from any target
	remove_diary_stack(yuno, 1)

# Watch effect on marked allies: when hit by a Harmful skill they shed a stack and brand the attacker.
func on_marked_ally_hit(context):
	if not context['source'].classes['Harmful']:
		return
	var holder = context['target']   # from_trigger_source sets target = the character that was hit
	var attacker = context['owner']
	if not holder.has_effect(DIARY, EffectType.Type.MARK):
		return
	# Breakdown protects the marked ALLY's stacks from removal; the enemy brand is always 1 turn
	# (a permanent brand would never be cleaned up and would permanently pad field-stack totals).
	if not breakdown_active(self.user):
		remove_diary_stack(holder, 1)
	if attacker != null and not (attacker.dead or attacker.banished):
		grant_diary_stack(attacker, 1, 2)

# ---- shared helpers ------------------------------------------------------

func breakdown_active(yuno):
	# True exactly while Breakdown's Mow Down swap is in effect — so the "cannot be removed" lock and
	# Axe Crazy's +5 stay perfectly in sync with Mow Down's availability (no separate flag to desync).
	for a in yuno.moveset.get_active_abilities(yuno):
		if a.ability_name == "Mow Down":
			return true
	return false

func total_diary_stacks(battle):
	var total = 0
	for c in battle.all_characters():
		var m = c.has_effect(DIARY, EffectType.Type.MARK)
		if m:
			total += m.stack_count()
	return total

func consume_all_diary(battle):
	var consumed = 0
	_consuming_diary = true   # suppress the Breakdown restore for these removals — Mow Down really consumes
	for c in battle.all_characters():
		var m = c.has_effect(DIARY, EffectType.Type.MARK)
		if m:
			consumed += m.stack_count()
			c.effects.erase_effect(m)
	_consuming_diary = false
	return consumed

func grant_diary_stack(target, n, dur = -1):
	var yuno = self.user
	var context = QueryContext.from_game_state(yuno, yuno.battle)
	_install_diary_restore_watch(target)
	var existing = target.has_effect(DIARY, EffectType.Type.MARK)
	if existing:
		existing.stacks = min(existing.stacks + n, MAX_DIARY_STACKS)
		existing.effect_updated.emit(existing)
	else:
		var stack_desc = func (eff):
			return "Marked with " + str(eff.stack_count()) + " stack(s) of Yukiteru Diary."
		var m = Effect.mark(dur, stack_desc)
		m.set_source(self)
		m.stackable = true
		m.display_stacks = true
		m.stacks = min(n, MAX_DIARY_STACKS)
		if target in yuno.team.characters:
			Character.add_allied_effect(context, yuno, target, m)
		else:
			Character.add_hostile_effect(context, yuno, target, m)
	# arm the receive-watch on allied holders (once). effect_name() == source.ability_name, so this
	# trigger is named "Yukiteru Diary" too (distinguished from the mark by its HARMFUL_RECEIVE_TRIGGER type).
	if target in yuno.team.characters and not target.has_effect(DIARY, EffectType.Type.HARMFUL_RECEIVE_TRIGGER, yuno):
		var watch = Effect.trigger_effect(Trigger.always(on_marked_ally_hit), EffectType.Type.HARMFUL_RECEIVE_TRIGGER, -1, "When hit by a Harmful skill, this ally loses a stack of Yukiteru Diary and marks the attacker.")
		watch.set_source(self)
		watch.system = true
		Character.add_allied_effect(context, yuno, target, watch)

func remove_diary_stack(target, n):
	var m = target.has_effect(DIARY, EffectType.Type.MARK)
	if not m:
		return
	m.stacks -= n
	if m.stacks <= 0:
		target.effects.erase_effect(m)
	else:
		m.effect_updated.emit(m)

# ---- Breakdown: "Yukiteru Diary cannot be removed from or expire on any target" ------------------
# Rather than gate every removal site, we watch each marked holder's effect_removed signal (every
# removal — Mow Down's consume, natural expiry of enemy brands, etc. — funnels through erase_effect,
# which emits it) and, while Breakdown is active, re-grant the removed stack at its ORIGINAL duration.

func _install_diary_restore_watch(holder):
	if holder in _diary_watched:
		return
	_diary_watched.append(holder)
	holder.effects.effect_removed.connect(_on_diary_effect_removed.bind(holder))

func _on_diary_effect_removed(removed_eff, holder):
	# Only Yukiteru Diary MARKs (the shared "Yukiteru Diary" name also tags a HARMFUL_RECEIVE_TRIGGER).
	if removed_eff.effect_type != EffectType.Type.MARK or removed_eff.effect_name() != DIARY:
		return
	# Mow Down consuming stacks is a real removal — Breakdown only blocks time-out expiry, not consume.
	if _consuming_diary:
		return
	var yuno = self.user
	if yuno == null or not is_instance_valid(yuno) or not breakdown_active(yuno):
		return
	if holder.dead or holder.banished:
		return
	# Yuno/ally stacks are permanent (dur -1); enemy brands are 1-turn (dur 2). Restore at the original.
	var dur = -1 if holder in yuno.team.characters else 2
	grant_diary_stack(holder, removed_eff.stack_count(), dur)
