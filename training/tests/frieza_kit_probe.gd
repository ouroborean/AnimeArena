extends Node

# Frieza end-to-end kit probe. Everything here is timing-sensitive, so the checks
# drive REAL turn boundaries (end_of_turn_effect_handling) rather than poking
# effects directly — the delayed payloads are exactly where a duration off-by-one
# would hide.
#   godot --headless --path <repo> res://training/tests/frieza_kit_probe.tscn

var fails := 0

func _check(c, l):
	if c:
		print("  PASS  " + l)
	else:
		fails += 1
		print("  FAIL  " + l)

func _build_player(u, names):
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u
	p.set_username(u)
	p.mission_reference = {}
	p.mission_data = {}
	p.bot_player = true
	p.bot_turn_delay = 0
	var is_enemy = (u == "BotEnemy")
	for n in names:
		p.recruit_character(Character.from_character_name(n), is_enemy)
	for c in p.team.characters:
		c.bot_character = true
	return p

func _cast(m, caster, idx, targets):
	var ab = caster.moveset.base_abilities[idx]
	caster.targeter.targets = targets
	caster.targeter.main_target = targets[0] if targets.size() > 0 else null
	caster.used_ability = ab
	ab.execute(caster, m)
	return ab

# One full turn boundary. end_of_turn_effect_handling already runs the acting side's
# end-of-turn triggers, ticks every duration, and calls turn_over() — which flips the
# side and fires BOTH teams' start-of-turn triggers. Doing any of that by hand here
# double-advances the clock.
func _pass_turn(m):
	m.end_of_turn_effect_handling()

# One WHOLE turn for the acting side, in battle_manager's real order:
#   1. the side's ticking effects are SNAPSHOTTED (process_turn_package:1601) -- before any ability,
#      which is why a ticker planted by `action` can never fire on its own cast turn;
#   2. the queued abilities execute;
#   3. the ticking batch runs LAST, because its keys are appended to true_execution_order at :1613;
#   4. the turn closes.
# `action` is an optional Callable that plays the ability slot. Sampling HP after _pass_turn alone
# attributes a ticking payout to the wrong turn -- that mistake has hidden real bugs before.
func _turn(m, action = null):
	var info = m.get_ticking_effect_information(m.waiting_for_turn)
	if action != null:
		action.call()
	for key in info:
		for eff in info[key]:
			m.execute_ticking_effect(eff)
	m.end_of_turn_effect_handling()

func _stunned(c) -> bool:
	return c.is_stunned(c.moveset.base_abilities[0])

# Invulnerability blocks add_hostile_effect, so leftover invuln from an earlier
# phase would silently swallow the stacks a later phase seeds.
func _reset_enemies(p, frieza):
	for c in p.team.characters:
		c.health.hp = c.health.max_hp
		for inv in c.effects.get_effects_by_type(EffectType.Type.INVULN):
			inv.end_effect()
		c.effects.remove_effect("Death Beam", EffectType.Type.MARK, frieza)

# Death Ball's timing is turn-parity sensitive, so tests that cast it must start from a known
# side. waiting_for_turn == true means the ENEMY side is acting (end_of_turn_effect_handling).
func _to_frieza_turn(m):
	for _i in range(4):
		if not m.waiting_for_turn:
			return
		m.end_of_turn_effect_handling()

func _heal_all(p):
	for c in p.team.characters:
		c.health.hp = c.health.max_hp

func _stacks(target, frieza) -> int:
	var e = target.has_effect("Death Beam", EffectType.Type.MARK, frieza)
	return e.stack_count() if e else 0

func _ready():
	print("=== frieza kit probe ===")
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", ["frieza", "naruto", "gon"])
	var p2 = _build_player("BotEnemy", ["eren", "misaka", "gray"])
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	var frieza = p1.team.characters[0]
	var foe = p2.team.characters[0]
	var foe2 = p2.team.characters[1]

	# ---- registration ----
	_check(frieza.character_name == "Frieza", "character builds (%s)" % frieza.character_name)
	_check(frieza.health.max_hp == 100, "max HP is 100 (got %d)" % frieza.health.max_hp)
	var names: Array = []
	for a in frieza.moveset.base_abilities:
		names.append(a.ability_name)
	_check(names == ["Death Beam", "Nova Strike", "Death Ball", "Telekinesis", "Death Beam Barrage", "Last Emperor"],
		"6 abilities in order: %s" % [names])
	var display: Array = []
	for a in frieza.moveset.display_abilities():
		display.append(a.ability_name)
	_check(not "Death Beam Barrage" in display and not "Last Emperor" in display,
		"Barrage + passive are hidden from the 4 display slots (%s)" % [display])

	# ---- Last Emperor installed itself at battle start ----
	_check(frieza.effects.get_effects_by_type(EffectType.Type.ON_DEATH_TRIGGER).size() == 1,
		"Last Emperor installed an ON_DEATH_TRIGGER via startup_passives")

	# ---- Death Beam: flat first, then +5/stack, and the pile is named after it ----
	var hp0 = foe.health.hp
	_cast(m, frieza, 0, [foe])
	_check(hp0 - foe.health.hp == 20, "Death Beam #1 deals 20 (dealt %d)" % (hp0 - foe.health.hp))
	_check(_stacks(foe, frieza) == 1, "Death Beam #1 leaves 1 stack (got %d)" % _stacks(foe, frieza))

	hp0 = foe.health.hp
	_cast(m, frieza, 0, [foe])
	_check(hp0 - foe.health.hp == 25, "Death Beam #2 deals 20+5 (dealt %d)" % (hp0 - foe.health.hp))
	_check(_stacks(foe, frieza) == 2, "Death Beam #2 -> 2 stacks (got %d)" % _stacks(foe, frieza))

	# 3rd use hands slot 0 to Barrage.
	hp0 = foe.health.hp
	_cast(m, frieza, 0, [foe])
	_check(hp0 - foe.health.hp == 30, "Death Beam #3 deals 20+10 (dealt %d)" % (hp0 - foe.health.hp))
	var slot0 = frieza.moveset.get_active_abilities(frieza)[0]
	_check(slot0.ability_name == "Death Beam Barrage",
		"3rd use swapped slot 0 to Death Beam Barrage (got %s)" % slot0.ability_name)

	# ---- Barrage: hits every stacked enemy, +5/stack, applies 2 ----
	_heal_all(p2)   # keep everyone alive: a death would cleanse the piles under the test
	_cast(m, frieza, 0, [foe2])   # give foe2 one stack so the AoE has two victims
	_check(_stacks(foe2, frieza) == 1, "foe2 seeded with 1 stack")
	var before_a = foe.health.hp
	var before_b = foe2.health.hp
	var sa = _stacks(foe, frieza)
	var sb = _stacks(foe2, frieza)
	_cast(m, frieza, 4, [foe, foe2])
	_check(before_a - foe.health.hp == 10 + 5 * sa,
		"Barrage hits foe for 10+5*%d (dealt %d)" % [sa, before_a - foe.health.hp])
	_check(before_b - foe2.health.hp == 10 + 5 * sb,
		"Barrage hits foe2 for 10+5*%d (dealt %d)" % [sb, before_b - foe2.health.hp])
	_check(_stacks(foe, frieza) == sa + 2, "Barrage adds 2 stacks to foe (%d -> %d)" % [sa, _stacks(foe, frieza)])
	_check(_stacks(foe2, frieza) == sb + 2, "Barrage adds 2 stacks to foe2 (%d -> %d)" % [sb, _stacks(foe2, frieza)])
	# Its stacks must merge into the SAME named pile, not start a second one.
	_check(foe.has_effect("Death Beam Barrage", EffectType.Type.MARK, frieza) == null,
		"Barrage did NOT start a parallel 'Death Beam Barrage' pile")

	# Barrage is unusable when nobody carries a stack.
	var clean = p2.team.characters[2]
	_check(_stacks(clean, frieza) == 0, "third enemy is unstacked")
	_heal_all(p2)
	foe.effects.remove_effect("Death Beam", EffectType.Type.MARK, frieza)
	foe2.effects.remove_effect("Death Beam", EffectType.Type.MARK, frieza)
	_check(not frieza.moveset.base_abilities[4].extra_usable(frieza),
		"Barrage is unusable with zero stacks on the field")
	_cast(m, frieza, 0, [foe])   # re-seed
	_check(frieza.moveset.base_abilities[4].extra_usable(frieza), "Barrage usable again once a stack exists")

	# ---- Nova Strike: shield now, payout on Frieza's NEXT turn, decaying by 5 ----
	_heal_all(p2)
	var nova = frieza.moveset.base_abilities[1]
	_check(nova.shield_amount(frieza) == 35, "Nova Strike starts at 35 shield")
	_cast(m, frieza, 1, [frieza])
	var sh = frieza.has_effect("Nova Strike", EffectType.Type.SHIELD, frieza)
	_check(sh != null and sh.mag == 35, "Nova Strike granted 35 Shield")
	_check(nova.shield_amount(frieza) == 30, "next Nova Strike will grant 30")

	var enemy_hp_before = [foe.health.hp, foe2.health.hp, clean.health.hp]
	# Close the CAST turn with _pass_turn, NOT _turn: the engine snapshots a side's ticking effects
	# before that turn's abilities run, so the ticker Nova Strike just planted was never in this
	# turn's batch. Running _turn here would gather it after the fact and fire it a turn early.
	_pass_turn(m)
	_check(frieza.has_effect("Nova Strike", EffectType.Type.SHIELD, frieza) != null,
		"Shield survives into the enemy's turn (that is the protection window)")
	var paid_early = false
	for i in range(3):
		if p2.team.characters[i].health.hp != enemy_hp_before[i]:
			paid_early = true
	_check(not paid_early, "Nova Strike did NOT pay out on the cast turn")

	# The ENEMY's whole turn. Ticking effects only run for the acting side, so Frieza's payout must
	# stay silent here even though the enemy's own ticking batch is dispatched.
	_turn(m)
	paid_early = false
	for i in range(3):
		if p2.team.characters[i].health.hp != enemy_hp_before[i]:
			paid_early = true
	_check(not paid_early, "Nova Strike did NOT pay out on the ENEMY's turn either")
	_check(frieza.has_effect("Nova Strike", EffectType.Type.SHIELD, frieza) != null,
		"the Shield is still standing going into Frieza's next turn")

	# Frieza's next turn: the payout resolves in the ticking slot, at the END of it.
	_turn(m)
	var paid := 0
	for i in range(3):
		paid += enemy_hp_before[i] - p2.team.characters[i].health.hp
	_check(paid == 35, "Nova Strike paid 35 to exactly one enemy at the end of Frieza's next turn (total %d)" % paid)
	_check(frieza.has_effect("Nova Strike", EffectType.Type.SHIELD, frieza) == null,
		"the Shield was spent as the projectile")

	# ...and it is a ONE-SHOT: nothing more on the turn after that.
	enemy_hp_before = [foe.health.hp, foe2.health.hp, clean.health.hp]
	_turn(m)
	_turn(m)
	var extra := 0
	for i in range(3):
		extra += enemy_hp_before[i] - p2.team.characters[i].health.hp
	_check(extra == 0, "the payout is one-shot -- nothing fired again two turns later (%d)" % extra)

	# A shield chipped down pays only the remainder.
	_to_frieza_turn(m)
	_cast(m, frieza, 1, [frieza])   # 30 this time
	var sh2 = frieza.has_effect("Nova Strike", EffectType.Type.SHIELD, frieza)
	_check(sh2 != null and sh2.mag == 30, "second Nova Strike granted 30")
	sh2.mag = 12   # simulate absorbing 18
	enemy_hp_before = [foe.health.hp, foe2.health.hp, clean.health.hp]
	_pass_turn(m)   # close the cast turn (its ticking batch predates the cast)
	_turn(m)        # the enemy's turn
	_turn(m)        # Frieza's next turn: payout
	paid = 0
	for i in range(3):
		paid += enemy_hp_before[i] - p2.team.characters[i].health.hp
	_check(paid == 12, "a partly-absorbed Shield pays only what remains (%d, expect 12)" % paid)

	# ---- Telekinesis ----
	_cast(m, frieza, 3, [frieza])
	_check(frieza.is_invuln(null), "Telekinesis made Frieza Invulnerable")

	# ---- Death Ball: nothing on cast, detonates at the end of the enemy's turn ----
	# Parity reset: every assertion below counts turn boundaries from Frieza's side, and the Nova
	# Strike block above no longer consumes a fixed number of them.
	_to_frieza_turn(m)
	_heal_all(p2)
	var db_hp = foe2.health.hp
	_cast(m, frieza, 2, [foe2])
	_check(foe2.health.hp == db_hp, "Death Ball deals nothing on cast")
	_pass_turn(m)   # start of enemy turn
	_check(foe2.health.hp == db_hp, "Death Ball has not gone off at the start of the enemy's turn")
	_pass_turn(m)   # end of enemy turn -> detonation
	_check(db_hp - foe2.health.hp == 35, "Death Ball dealt 35 at the end of the following turn (dealt %d)" % (db_hp - foe2.health.hp))
	_check(_stunned(foe2), "Death Ball stunned the target")
	# The stun has to be live on the enemy's NEXT turn and gone after it — that is the whole
	# claim of "stunned for 1 turn". Assert against the ACTING side rather than counting
	# boundaries: end_of_turn_effect_handling treats waiting_for_turn == true as "the enemy
	# side is acting", so that flag is the ground truth for whose turn it is.
	_check(not m.waiting_for_turn, "the bomb went off at the end of the enemy's turn; Frieza acts now")
	_pass_turn(m)
	_check(m.waiting_for_turn, "now it is the enemy's turn")
	_check(_stunned(foe2), "stun is live on the enemy's turn -- the turn it costs them")
	_pass_turn(m)
	_check(not m.waiting_for_turn, "back to Frieza's side")
	_check(not _stunned(foe2), "stun expires after exactly one enemy turn (not two)")

	# Invulnerable at resolve time = no damage, no stun.
	db_hp = foe.health.hp
	_cast(m, frieza, 2, [foe])
	var inv = Effect.invuln_effect(4)
	inv.set_source(frieza.moveset.base_abilities[3])
	Character.add_allied_effect(QueryContext.from_game_state(foe, m), foe, foe, inv)
	_pass_turn(m)
	_pass_turn(m)
	_check(foe.health.hp == db_hp, "Death Ball fizzles against an Invulnerable target")
	_check(not _stunned(foe), "no stun when the bomb fizzles")

	# ---- Last Emperor: 20 to every enemy at 4+ stacks, and nothing below 4 ----
	_reset_enemies(p2, frieza)
	var big = p2.team.characters[0]
	var small = p2.team.characters[1]
	var ctx = QueryContext.from_game_state(frieza, m)
	Character.add_hostile_effect(ctx, frieza, big, frieza.moveset.base_abilities[0].build_stack(4))
	Character.add_hostile_effect(ctx, frieza, small, frieza.moveset.base_abilities[0].build_stack(3))
	_check(_stacks(big, frieza) == 4 and _stacks(small, frieza) == 3, "seeded 4 and 3 stacks")
	big.health.hp = 90
	small.health.hp = 90
	clean.health.hp = 90
	frieza.die(big, null)
	_check(90 - big.health.hp == 20, "Last Emperor hit the 4-stack enemy for 20 (dealt %d)" % (90 - big.health.hp))
	_check(small.health.hp == 90, "the 3-stack enemy was NOT hit")
	_check(clean.health.hp == 90, "the unstacked enemy was NOT hit")

	# =====================================================================================
	# Regressions for the defects the adversarial review confirmed. Each of these FAILED
	# before the fix, so they are the part of this probe worth keeping.
	# =====================================================================================
	# The Last Emperor block above KILLED Frieza, and can_apply_allied_effect requires is_alive —
	# without this every buff below silently no-ops and the regressions read as false failures.
	frieza.dead = false
	frieza.health.hp = frieza.health.max_hp
	_reset_enemies(p2, frieza)
	frieza.effects.remove_effect("Death Beam Focus", EffectType.Type.MARK, frieza)
	frieza.effects.remove_effect("Nova Strike Decay", EffectType.Type.MARK, frieza)
	for sw in frieza.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		sw.end_effect()

	# (1) Barrage must not reach into the CASTER's moveset for its stack factory: a copy/steal
	# mechanic runs it from someone whose base_abilities[0] has no build_stack() at all.
	var thief = p1.team.characters[1]          # Naruto — no build_stack anywhere in his kit
	var victim = p2.team.characters[0]
	var stolen = Ability.from_database("frieza5")
	stolen.user = thief
	add_child(stolen)
	# Frieza's own pile on the same victim, so the two piles can be told apart afterwards.
	Character.add_hostile_effect(QueryContext.from_game_state(frieza, m), frieza, victim,
		frieza.moveset.base_abilities[0].build_stack(2))
	# ...and the thief's own pile, which is what their copy of Barrage reads and grows.
	Character.add_hostile_effect(QueryContext.from_game_state(thief, m), thief, victim,
		stolen.build_stack(2))
	thief.targeter.targets = [victim]
	thief.targeter.main_target = victim
	thief.used_ability = stolen
	var vic_hp = victim.health.hp
	stolen.execute(thief, m)   # would abort on "Nonexistent function 'build_stack'" before the fix
	# EXACT: Barrage is 10 + 5 per stack, and the thief brought 2 stacks, so 20. "Any nonzero
	# damage" would pass on a half-executed Barrage that aborted after its base hit.
	_check(vic_hp - victim.health.hp == 20,
		"a stolen Barrage executes IN FULL from a non-Frieza caster: 10 + 5x2 = 20 (dealt %d)" % (vic_hp - victim.health.hp))
	var thief_pile = victim.has_effect("Death Beam", EffectType.Type.MARK, thief)
	_check(thief_pile != null and thief_pile.stack_count() == 4,
		"the thief's stacks merge into their OWN 'Death Beam' pile (2 -> %d)" % [thief_pile.stack_count() if thief_pile else -1])
	_check(_stacks(victim, frieza) == 2, "Frieza's own pile on that target is untouched by the thief's")

	# (2) Silence must not eat the every-3rd-use swap. Death Beam is Damaging, so a silenced
	# Frieza can still cast it — and since the Silence v2 rewrite the engine applies the swap fine.
	_reset_enemies(p2, frieza)
	frieza.effects.remove_effect("Death Beam Focus", EffectType.Type.MARK, frieza)
	var sil = Effect.silence_effect(6)
	sil.set_source(frieza.moveset.base_abilities[0])
	Character.add_allied_effect(QueryContext.from_game_state(frieza, m), frieza, frieza, sil)
	_check(frieza.is_silenced(), "Frieza is silenced")
	_check(not frieza.moveset.base_abilities[0].is_silenced_out(frieza),
		"Death Beam is Damaging, so silence does not lock it out")
	var live = p2.team.characters[0]
	for i in range(3):
		_cast(m, frieza, 0, [live])
	_check(frieza.moveset.get_active_abilities(frieza)[0].ability_name == "Death Beam Barrage",
		"the 3rd use still swaps in Barrage while silenced (got %s)" % frieza.moveset.get_active_abilities(frieza)[0].ability_name)
	frieza.effects.remove_effect("Death Beam", EffectType.Type.SILENCE, frieza)
	for sw2 in frieza.effects.get_effects_by_type(EffectType.Type.ABILITY_SWAP):
		sw2.end_effect()

	# (3) Death Ball must not detonate on the turn it lands. A bounce-reflect can re-aim it onto
	# Frieza's own side, where an end-of-turn trigger fires during the very turn it was planted.
	_reset_enemies(p2, frieza)
	var ally = p1.team.characters[2]
	frieza.targeter.targets = [ally]
	frieza.targeter.main_target = ally
	frieza.used_ability = frieza.moveset.base_abilities[2]
	var ally_hp = ally.health.hp
	frieza.moveset.base_abilities[2].execute(frieza, m)   # simulate the reflected landing
	_pass_turn(m)   # end of Frieza's own turn: the bomb's host team IS acting
	_check(ally.health.hp == ally_hp,
		"a bomb that landed on Frieza's own side does NOT go off the same turn (hp %d -> %d)" % [ally_hp, ally.health.hp])

	# (4) Class-restricted invulnerability must not blanket-fizzle the bomb. is_invuln(null)
	# short-circuits true for ANY invuln; passing the ability reaches the class tests.
	for stray in ally.effects.get_effects_by_type(EffectType.Type.END_OF_TURN_TRIGGER):
		stray.end_effect()      # clear the reflected bomb left armed by (3)
	_to_frieza_turn(m)
	_reset_enemies(p2, frieza)
	var picky = p2.team.characters[1]
	picky.health.hp = 100
	var partial = Effect.invuln_effect(6, ["Physical"])   # invulnerable to PHYSICAL skills only
	partial.set_source(frieza.moveset.base_abilities[3])
	Character.add_allied_effect(QueryContext.from_game_state(picky, m), picky, picky, partial)
	_check(picky.is_invuln(null), "the target reads as invulnerable to a null-ability query")
	_check(not picky.is_invuln(frieza.moveset.base_abilities[2]),
		"...but NOT to Death Ball, which is Energy, not Physical")
	var picky_hp = picky.health.hp
	_cast(m, frieza, 2, [picky])
	_pass_turn(m)
	_pass_turn(m)
	_check(picky_hp - picky.health.hp == 35,
		"Death Ball still lands through Physical-only invulnerability (dealt %d)" % (picky_hp - picky.health.hp))

	# (5) Nova Strike's decay counter must survive an enemy buff-strip, or a hostile skill would
	# hand Frieza a full-strength 35 shield back.
	frieza.effects.remove_effect("Nova Strike Decay", EffectType.Type.MARK, frieza)
	_cast(m, frieza, 1, [frieza])
	_check(frieza.moveset.base_abilities[1].shield_amount(frieza) == 30, "decayed to 30 after one use")
	frieza.effects.cleanse_all_ally_effects(frieza)
	_check(frieza.moveset.base_abilities[1].shield_amount(frieza) == 30,
		"a buff-strip does NOT reset Nova Strike to 35 (got %d)" % frieza.moveset.base_abilities[1].shield_amount(frieza))

	print("=== probe done: %d failure(s) ===" % fails)
	get_tree().quit(fails)
