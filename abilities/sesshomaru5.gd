extends Ability

# Perfect Daiyoukai (Passive). Two clauses:
#   (1) Incoming Stuns are shortened by 1 turn (3-turn cooldown). The mechanic is the on_stun_received
#       override in character/sesshomaru.gd; this passive owns the VISIBLE state: a "Perfect Daiyoukai" MARK
#       that reads "active" (permanent) when ready and is swapped for a ticking "recharging" MARK (the
#       cooldown) when a Stun is shortened. START_OF_TURN re-adds the "ready" MARK once the recharge fades.
#   (2) While Sesshomaru is at 50 or less HP he ignores enemy effects that reduce his damage — a
#       shrug of enemy DAMAGE_MOD, toggled on/off as his HP crosses 50 (the arima5 START_OF_TURN pattern).

const PASSIVE := "Perfect Daiyoukai"
const STUN_COOLDOWN := 6   # 3 turns — MARK durations tick on BOTH teams' turn-starts (2 per round)

func describe(user):
	return "If Sesshomaru receives a Stun, its duration is reduced by 1 turn (minimum 0); this has a 3 turn cooldown. While Sesshomaru is at 50 or less HP, he ignores harmful effects that would reduce his damage."

func split_desc():
	return [
		["Incoming Stuns on Sesshomaru are shortened by 1 turn, minimum 0 (3 turn cooldown)", Color.AQUAMARINE],
		["While at 50 or less HP, ignores harmful effects that would reduce his damage", Color.AQUAMARINE],
	]

func execute(user, battle):
	var context = QueryContext.from_game_state(user, battle)
	if user.has_effect(PASSIVE, EffectType.Type.START_OF_TURN_TRIGGER, user) == null:
		var t = Effect.trigger_effect(Trigger.always(on_turn_start), EffectType.Type.START_OF_TURN_TRIGGER, -1, "")
		t.name_override = PASSIVE
		t.set_source(self)
		t.system = true
		t.invisible = true
		t.remove_on_death = false
		t.cleansable = false
		Character.add_allied_effect(context, user, user, t)
	_maintain_damage_ignore(user)     # immediate evaluation at battle start
	_maintain_stun_indicator(user)    # show the "Perfect Daiyoukai active" indicator from turn 1

func on_turn_start(context):
	var sessh = context['effect'].user
	if sessh == null:
		return
	_maintain_damage_ignore(sessh)
	_maintain_stun_indicator(sessh)   # re-show "active" once the recharge MARK has faded

# Toggle the "ignore enemy damage-reducers" self-buff on/off as HP crosses 50 (add if low & absent, erase if
# high & present). shrug_off_type(DAMAGE_MOD) only skips ENEMY DAMAGE_MOD in get_true_damage, so Sesshomaru's
# own damage boosts are unaffected.
func _maintain_damage_ignore(sessh):
	if sessh == null or sessh.battle == null:
		return
	var present = sessh.has_effect(PASSIVE, EffectType.Type.IGNORE_EFFECT, sessh)
	var low = not sessh.dead and sessh.health.hp <= 50
	if low and present == null:
		var ig = Effect.ignore_effect_effect(-1, EffectType.Type.DAMAGE_MOD)
		ig.name_override = PASSIVE
		ig.description = func(eff): return "This character ignores harmful effects that would reduce his damage."
		ig.set_source(self)
		ig.system = true
		ig.display_system = true
		ig.remove_on_death = false
		ig.cleansable = false
		var ctx = QueryContext.from_game_state(sessh, sessh.battle)
		Character.add_allied_effect(ctx, sessh, sessh, ig)
	elif not low and present != null:
		sessh.effects.erase_effect(present)

# ── Perfect Daiyoukai stun-protection display. One visible "Perfect Daiyoukai" MARK: permanent (dur -1) =
# ── "active/ready"; a finite ticking MARK = "recharging" (the visible cooldown). on_stun_received drives it.
func stun_on_cooldown(sessh) -> bool:
	var m = sessh.has_effect(PASSIVE, EffectType.Type.MARK, sessh)
	return m != null and m.duration != -1   # a finite MARK = the recharge is running

func begin_stun_cooldown(sessh):
	var m = sessh.has_effect(PASSIVE, EffectType.Type.MARK, sessh)
	if m != null:
		sessh.effects.erase_effect(m)   # drop the "ready" marker
	var cd = Effect.mark(STUN_COOLDOWN, "Perfect Daiyoukai is recharging: Sesshomaru cannot shorten another Stun until this fades.")
	cd.name_override = PASSIVE
	cd.set_source(self)
	cd.system = true
	cd.display_system = true   # visible to both, but protected machinery (not cleansable)
	cd.remove_on_death = false
	cd.cleansable = false
	Character.add_allied_effect(QueryContext.from_game_state(sessh, sessh.battle), sessh, sessh, cd)

func _maintain_stun_indicator(sessh):
	if sessh == null or sessh.dead or sessh.battle == null:
		return
	if sessh.has_effect(PASSIVE, EffectType.Type.MARK, sessh) == null:   # neither ready nor recharging present
		var ready = Effect.mark(-1, "Perfect Daiyoukai is active: the next Stun Sesshomaru receives is shortened by 1 turn (minimum 0).")
		ready.name_override = PASSIVE
		ready.set_source(self)
		ready.system = true
		ready.display_system = true
		ready.remove_on_death = false
		ready.cleansable = false
		Character.add_allied_effect(QueryContext.from_game_state(sessh, sessh.battle), sessh, sessh, ready)

func extra_usable(user):
	return true

func target(user, battle):
	default_self_target_function(user, battle)
