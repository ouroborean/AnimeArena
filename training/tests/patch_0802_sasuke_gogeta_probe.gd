extends Node

# Patch 2026-08-02 — probe for the Sasuke / Itachi / Lucy / Erza / Mavis / Muichiro /
# Shokuhou / Rakko / Mash / Gogeta / Android 17 / Broly / Yubel cluster.
#
# WHY A PROBE RATHER THAN A COMPILE: every change here fails SILENTLY. A wrong
# duration, a stack cap that guards AFTER the merge instead of before it, a
# targeting restriction that never narrows anything, an ability swap that is never
# taken back — all of them load, render and play a whole match without an error.
#
# The two that most need watching:
#   LUCY    Raising Aquarius's base duration to 4 makes the old `if duration == 4`
#           gate true for the NON-Gemini case, handing out the Gemini damage repeat
#           on every cast. No error, no log, just a quietly much stronger skill.
#   BROLY   There is no engine stack cap; effect_storage merges unconditionally, so
#           a guard written after add_allied_effect reads a number that already
#           includes the stack it was supposed to refuse.
#
# ASSERTION ORDER: each block asserts the POSITIVE (the new behaviour happened)
# before any negative control, so no block can pass against a no-op edit.
#
#   godot --headless --path <repo> res://training/tests/patch_0802_sasuke_gogeta_probe.tscn

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

# Each block gets its own battle so no block can be contaminated by the effects a
# previous one planted.
func _battle(a, b):
	var m := BattleManager.new()
	m.name = "BattleManager"
	m.shadow_mode = true
	add_child(m)
	var p1 = _build_player("BotPlayer", a)
	var p2 = _build_player("BotEnemy", b)
	m.start_battle(p1, p2, true, 99, BattleManager.MatchType.BOT)
	for colour in [Energy.Type.GREEN, Energy.Type.BLUE, Energy.Type.WHITE, Energy.Type.RED]:
		p1.team.energy.pool[colour] = 20
		p2.team.energy.pool[colour] = 20
	for c in p1.team.characters + p2.team.characters:
		c.refresh()
	return [m, p1.team.characters, p2.team.characters]

func _ctx(m, c):
	return QueryContext.from_game_state(c, m)

# execute() is driven directly here rather than through the turn loop, so
# used_ability has to be set by hand — resolve_damage/resolve_healing read
# owner.used_ability and a null there raises inside the engine.
func _use(c, ability, targets):
	c.targeter.targets = targets
	c.targeter.main_target = targets[0] if targets.size() > 0 else null
	c.used_ability = ability
	ability.execute(c, c.battle)

# One duration tick == the end of one player's turn.
func _tick(c, n := 1):
	for i in range(n):
		c.effects.tick_all_effects_durations()

func _named(c, ability_name, eff_type, owner = null):
	return c.effects.has_effect(ability_name, eff_type, owner)

func _pool_total(c) -> int:
	var t = 0
	for k in c.team.energy.pool:
		t += c.team.energy.pool[k]
	return t


func _ready():
	print("=== patch 2026-08-02 probe: sasuke/lucy/gogeta/shokuhou/rakko/mash/itachi/statics ===")
	_sasuke()
	_lucy()
	_gogeta()
	_shokuhou()
	_rakko_mash_itachi()
	_statics()
	print("=== %d failure(s) ===" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------------------
# SASUKE — permanent mark, permanent Kirin swap, Kirin's +10, Kirin retiring itself.
# ---------------------------------------------------------------------------
func _sasuke():
	print("-- Sasuke: Great Dragon Fire / Kirin --")
	var b = _battle(["sasuke", "naruto", "gon"], ["gray", "eren", "misaka"])
	var m = b[0]
	var sasuke = b[1][0]
	var foe = b[2][0]
	var gdf = sasuke.moveset.base_abilities[2]
	var kirin = sasuke.moveset.base_abilities[5]
	_check(gdf.ability_name == "Great Dragon Fire", "slot 3 is Great Dragon Fire (got %s)" % gdf.ability_name)
	_check(kirin.ability_name == "Kirin", "slot 6 is Kirin (got %s)" % kirin.ability_name)

	_use(sasuke, gdf, [foe])
	var mark = foe.marked_by("Great Dragon Fire", sasuke)
	_check(mark != null, "POSITIVE: Great Dragon Fire marked the enemy")
	_check(mark != null and mark.duration == -1,
		"POSITIVE: the mark is PERMANENT (dur %s, expect -1)" % [mark.duration if mark else "none"])

	# The swap is planted by the delay effect's wrapup, after dur 4 == 2 turns.
	_tick(sasuke, 4)
	var swap = _named(sasuke, "Great Dragon Fire", EffectType.Type.ABILITY_SWAP, sasuke)
	_check(swap != null, "POSITIVE: the Kirin swap landed after the 2-turn delay")
	_check(swap != null and swap.duration == -1,
		"POSITIVE: the Kirin swap is PERMANENT (dur %s, expect -1)" % [swap.duration if swap else "none"])
	_tick(sasuke, 4)
	_check(_named(sasuke, "Great Dragon Fire", EffectType.Type.ABILITY_SWAP, sasuke) != null,
		"[control] it survives four more ticks — the old dur-2 window is long past")

	# +10 against the marked enemy. SAME target for both casts, so every passive,
	# damage-mod and reduction on both sides is held constant; only the mark moves.
	foe.health.hp = 100
	_use(sasuke, kirin, [foe])
	var marked_damage = 100 - foe.health.hp
	_check(_named(sasuke, "Great Dragon Fire", EffectType.Type.ABILITY_SWAP, sasuke) == null,
		"POSITIVE: using Kirin removed the swap, handing slot 3 back to Great Dragon Fire")

	foe.effects.remove_effect("Great Dragon Fire", EffectType.Type.MARK, sasuke)
	_check(foe.marked_by("Great Dragon Fire", sasuke) == null, "[setup] the mark is cleared for the control cast")
	foe.health.hp = 100
	_use(sasuke, kirin, [foe])
	var plain_damage = 100 - foe.health.hp
	_check(marked_damage - plain_damage == 10,
		"POSITIVE: Kirin deals exactly 10 more to the marked enemy (%d vs %d)" % [marked_damage, plain_damage])


# ---------------------------------------------------------------------------
# LUCY — the `if duration == 4` regression.
# ---------------------------------------------------------------------------
func _lucy():
	print("-- Lucy: Aquarius 2 turns / 3 under Gemini --")
	var b = _battle(["lucy", "naruto", "gon"], ["gray", "eren", "misaka"])
	var m = b[0]
	var lucy = b[1][0]
	var ally_a = b[1][1]
	var ally_b = b[1][2]
	var foe_a = b[2][0]
	var foe_b = b[2][1]
	var aquarius = lucy.moveset.base_abilities[0]
	var gemini = lucy.moveset.base_abilities[1]
	_check(aquarius.ability_name == "Aquarius", "slot 1 is Aquarius")
	_check(gemini.ability_name == "Gemini", "slot 2 is Gemini")

	_use(lucy, aquarius, [foe_a, ally_a])
	var dr = _named(ally_a, "Aquarius", EffectType.Type.DAMAGE_REDUCTION, lucy)
	_check(dr != null and dr.duration == 4,
		"POSITIVE: base Damage Reduction runs 2 turns (dur %s, expect 4)" % [dr.duration if dr else "none"])
	_check(_named(foe_a, "Aquarius", EffectType.Type.DAMAGE, lucy) == null,
		"POSITIVE: a NON-Gemini cast plants NO damage repeat (this is the `duration == 4` regression)")

	_use(lucy, gemini, [lucy])
	_check(lucy.marked_by("Gemini", lucy) != null, "[setup] Gemini is up")
	_use(lucy, aquarius, [foe_b, ally_b])
	var dr2 = _named(ally_b, "Aquarius", EffectType.Type.DAMAGE_REDUCTION, lucy)
	_check(dr2 != null and dr2.duration == 6,
		"POSITIVE: under Gemini the Damage Reduction runs 3 turns (dur %s, expect 6)" % [dr2.duration if dr2 else "none"])
	var rep = _named(foe_b, "Aquarius", EffectType.Type.DAMAGE, lucy)
	_check(rep != null, "POSITIVE: under Gemini the damage repeat IS planted")
	_check(rep != null and rep.duration == 5,
		"POSITIVE: the repeat is 2N-1 == 5, so 3 total turns of damage counting the cast (dur %s)" % [rep.duration if rep else "none"])


# ---------------------------------------------------------------------------
# GOGETA — visible stance; an untriggered stance pays out; a triggered one does not;
# the instant path must NOT swap Bluff Kamehameha in.
# ---------------------------------------------------------------------------
func _gogeta():
	print("-- Gogeta: Unapproachable Stance / Big Bang Kamehameha --")
	var b = _battle(["gogeta", "naruto", "gon"], ["gray", "eren", "misaka"])
	var m = b[0]
	var gogeta = b[1][0]
	var foe = b[2][0]
	var bigbang = gogeta.moveset.base_abilities[0]
	var stance = gogeta.moveset.base_abilities[3]
	_check(bigbang.ability_name == "Big Bang Kamehameha", "slot 1 is Big Bang Kamehameha")
	_check(stance.ability_name == "Unapproachable Stance", "slot 4 is Unapproachable Stance")

	_use(gogeta, stance, [gogeta])
	var trig = _named(gogeta, "Unapproachable Stance", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, gogeta)
	_check(trig != null, "[setup] the stance trigger landed")
	_check(trig != null and not trig.invisible, "POSITIVE: the stance is no longer Invisible")

	_tick(gogeta, 2)
	var payoff = gogeta.marked_by("Unapproachable Stance", gogeta)
	_check(payoff != null, "POSITIVE: an UNTRIGGERED stance expiring plants the instant-strike mark")
	_check(payoff != null and payoff.duration == 2,
		"POSITIVE: that mark covers exactly the following turn (dur %s, expect 2)" % [payoff.duration if payoff else "none"])

	foe.health.hp = 100
	_use(gogeta, bigbang, [foe])
	_check(foe.health.hp < 100, "POSITIVE: Big Bang struck INSTANTLY (foe hp %d)" % foe.health.hp)
	_check(_named(foe, "Big Bang Kamehameha", EffectType.Type.TICKING_TRIGGER, gogeta) == null,
		"POSITIVE: the instant path plants no charging ticker")
	_check(_named(gogeta, "Big Bang Kamehameha", EffectType.Type.ABILITY_SWAP, gogeta) == null,
		"POSITIVE: Bluff Kamehameha is NOT swapped in (gogeta5 would have zero legal targets)")
	_check(gogeta.marked_by("Unapproachable Stance", gogeta) == null, "the instant-strike mark was consumed")

	# Control A: a stance somebody DID trigger must not pay out.
	_use(gogeta, stance, [gogeta])
	var trig2 = _named(gogeta, "Unapproachable Stance", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, gogeta)
	trig2.storage["fired"] = true
	_tick(gogeta, 2)
	_check(gogeta.marked_by("Unapproachable Stance", gogeta) == null,
		"[control] a TRIGGERED stance expiring pays out nothing")

	# Control B: with no mark Big Bang charges the old way.
	foe.health.hp = 100
	_use(gogeta, bigbang, [foe])
	_check(_named(foe, "Big Bang Kamehameha", EffectType.Type.TICKING_TRIGGER, gogeta) != null,
		"[control] without the mark Big Bang charges as before")
	_check(_named(gogeta, "Big Bang Kamehameha", EffectType.Type.ABILITY_SWAP, gogeta) != null,
		"[control] ...and swaps Bluff Kamehameha in as before")


# ---------------------------------------------------------------------------
# SHOKUHOU — the 10 Piercing window must track `duration`, including Exterior's +4.
# ---------------------------------------------------------------------------
func _shokuhou():
	print("-- Shokuhou: Mental Out's per-turn Piercing --")
	var b = _battle(["shokuhou", "naruto", "gon"], ["gray", "eren", "misaka"])
	var m = b[0]
	var shokuhou = b[1][0]
	var foe = b[2][0]
	var other = b[2][1]
	var mental_out = shokuhou.moveset.base_abilities[0]
	_check(mental_out.ability_name == "Mental Out", "slot 1 is Mental Out")

	foe.health.hp = 100
	_use(shokuhou, mental_out, [foe])
	_check(foe.health.hp < 100, "POSITIVE: the 10 Piercing lands on the CAST turn (hp %d)" % foe.health.hp)
	var dot = _named(foe, "Mental Out", EffectType.Type.DAMAGE, shokuhou)
	var stun = _named(foe, "Mental Out", EffectType.Type.STUN, shokuhou)
	_check(dot != null, "POSITIVE: a per-turn Piercing effect was planted")
	_check(dot != null and dot.damage_type == DamageType.Type.PIERCING, "the tick is Piercing")
	_check(dot != null and stun != null and dot.duration == stun.duration,
		"POSITIVE: the damage window equals the stun window (%s vs %s)"
			% [dot.duration if dot else "none", stun.duration if stun else "none"])

	# Exterior extends `duration` 3 -> 7. A literal in the damage effect would
	# silently leave it at 3 and the damage would stop four ticks early.
	var ext = Effect.mark(6, "Exterior")
	ext.name_override = "Exterior"
	ext.set_source(mental_out)
	Character.add_allied_effect(_ctx(m, shokuhou), shokuhou, shokuhou, ext)
	_check(shokuhou.marked_by("Exterior") != null, "[setup] Exterior is up")
	_use(shokuhou, mental_out, [other])
	var dot2 = _named(other, "Mental Out", EffectType.Type.DAMAGE, shokuhou)
	var stun2 = _named(other, "Mental Out", EffectType.Type.STUN, shokuhou)
	_check(dot2 != null and dot2.duration == 7,
		"POSITIVE: with Exterior consumed the damage window is 7, not 3 (got %s)" % [dot2.duration if dot2 else "none"])
	_check(dot2 != null and stun2 != null and dot2.duration == stun2.duration,
		"POSITIVE: ...and it still matches the extended stun window")


# ---------------------------------------------------------------------------
# RAKKO (free-cast targeting), MASH (the Knight discount), ITACHI (Kotoamatsukami).
# ---------------------------------------------------------------------------
func _rakko_mash_itachi():
	print("-- Rakko / Mash / Itachi --")
	var b = _battle(["rakko", "mash", "itachi"], ["gray", "eren", "misaka"])
	var m = b[0]
	var rakko = b[1][0]
	var mash = b[1][1]
	var itachi = b[1][2]
	var foes = b[2]

	# --- Rakko: while free, only Wave-Tracking-Shattered enemies are targetable.
	var rifle = rakko.moveset.base_abilities[1]
	var tracking = rakko.moveset.base_abilities[4]
	_check(rifle.ability_name == "Close-Range Rifle", "rakko2 is Close-Range Rifle (got %s)" % rifle.ability_name)
	_check(tracking.ability_name == "Wave Tracking", "rakko5 is Wave Tracking (got %s)" % tracking.ability_name)

	var baseline = _targetable(m, rakko, rifle)
	_check(baseline.size() >= 2, "[baseline] with nobody Shattered it can aim at %d enemies" % baseline.size())
	var base_cost = 0
	for e in rifle.cost():
		base_cost += rifle.cost()[e]
	_check(base_cost > 0, "[baseline] and it is not free (cost %d)" % base_cost)

	var shatter = Effect.def_negate(-1)
	shatter.set_source(tracking)
	Character.add_hostile_effect(_ctx(m, rakko), rakko, foes[1], shatter)
	var restricted = _targetable(m, rakko, rifle)
	_check(restricted.size() == 1 and restricted[0] == foes[1],
		"POSITIVE: while free it can ONLY aim at the Shattered enemy (%d candidate(s))" % restricted.size())
	var free_total = 0
	for e in rifle.cost():
		free_total += rifle.cost()[e]
	_check(free_total == 0, "POSITIVE: ...and the same state is what makes it free (total %d)" % free_total)

	# --- Mash: A Knight That Protects ending discounts Around Round Crash.
	var crash = mash.moveset.base_abilities[1]
	var vow = mash.moveset.base_abilities[3]
	_check(crash.ability_name == "Around Round Crash", "mash2 is Around Round Crash")
	_check(vow.ability_name == "A Knight That Protects", "mash4 is A Knight That Protects")
	_check(crash.base_damage == 15, "POSITIVE: Around Round Crash base damage is 15 (got %d)" % crash.base_damage)
	_use(mash, vow, [rakko])
	var vow_shield = _named(mash, "A Knight That Protects", EffectType.Type.SHIELD, mash)
	_check(vow_shield != null, "[setup] the vow Shield is up")
	_check(int(crash.cost().get(Energy.Type.RANDOM, 0)) == 1,
		"[baseline] Around Round Crash costs 1 Random while the vow holds")
	mash.call_unique("mash", "break_vow", [QueryContext.from_effect_end(vow_shield)])
	var discount = _named(mash, "A Knight That Protects", EffectType.Type.COST_MOD, mash)
	_check(discount != null, "POSITIVE: breaking the vow planted the Around Round Crash discount")
	_check(discount != null and discount.duration == 2,
		"POSITIVE: the discount lasts 1 turn (dur %s, expect 2)" % [discount.duration if discount else "none"])
	_check(discount != null and discount.ability_targets == ["Around Round Crash"],
		"POSITIVE: it names ONLY Around Round Crash (got %s)" % [discount.ability_targets if discount else "none"])
	_check(int(crash.cost().get(Energy.Type.RANDOM, 0)) == 0,
		"POSITIVE: Around Round Crash now costs 0 Random")

	# --- Itachi: Kotoamatsukami runs 2 turns on BOTH branches.
	var koto = itachi.moveset.base_abilities[2]
	_check(koto.ability_name == "Kotoamatsukami", "itachi3 is Kotoamatsukami")
	_use(itachi, koto, [foes[0]])
	var use_ctr = _named(foes[0], "Kotoamatsukami", EffectType.Type.COUNTER_USE, itachi)
	_check(use_ctr != null and use_ctr.duration == 4,
		"POSITIVE: the hostile COUNTER_USE branch runs 2 turns (dur %s, expect 4)" % [use_ctr.duration if use_ctr else "none"])
	_use(itachi, koto, [rakko])
	var recv_ctr = _named(rakko, "Kotoamatsukami", EffectType.Type.COUNTER_RECEIVE, itachi)
	_check(recv_ctr != null and recv_ctr.duration == 4,
		"POSITIVE: the allied COUNTER_RECEIVE branch runs 2 turns too (dur %s, expect 4)" % [recv_ctr.duration if recv_ctr else "none"])


# Re-run an ability's targeting from a clean slate and collect who it lit up.
func _targetable(m, caster, ability) -> Array:
	for c in m.all_characters():
		c.targeted = false
	ability.target(caster, m)
	var out := []
	for c in m.all_characters():
		if c.targeted:
			out.append(c)
	return out


# ---------------------------------------------------------------------------
# Literals and thresholds: Erza, Mavis, Muichiro, Broly, Yubel, Android 17.
# ---------------------------------------------------------------------------
func _statics():
	print("-- Erza / Mavis / Muichiro / Broly / Yubel / Android 17 --")
	var b = _battle(["mavis", "erza", "muichiro"], ["broly", "yubel", "seventeen"])
	var m = b[0]
	var mavis = b[1][0]
	var erza = b[1][1]
	var muichiro = b[1][2]
	var broly = b[2][0]
	var yubel = b[2][1]
	var seventeen = b[2][2]

	# --- Erza: Queen of Fairies grants 15 Shield.
	var qof = erza.moveset.base_abilities[3]
	_check(qof.ability_name == "Queen of Fairies", "erza4 is Queen of Fairies")
	_use(erza, qof, [erza])
	var eshield = _named(erza, "Queen of Fairies", EffectType.Type.SHIELD, erza)
	_check(eshield != null and eshield.mag == 15,
		"POSITIVE: Queen of Fairies grants 15 Shield (got %s)" % [eshield.mag if eshield else "none"])
	_check(eshield != null and eshield.duration == 2,
		"its 1-turn duration is untouched (dur %s)" % [eshield.duration if eshield else "none"])

	# --- Mavis: Fairy Heart is Shield, not Invulnerability, and needs no living ally.
	var heart = mavis.moveset.base_abilities[3]
	_check(heart.ability_name == "Fairy Heart", "mavis4 is Fairy Heart")
	for ally in mavis.team.characters:
		if ally != mavis:
			ally.dead = true
	_check(heart.extra_usable(mavis), "POSITIVE: Fairy Heart is usable with no living ally")
	for ally in mavis.team.characters:
		if ally != mavis:
			ally.dead = false
	_use(mavis, heart, [mavis])
	var mshield = _named(mavis, "Fairy Heart", EffectType.Type.SHIELD, mavis)
	_check(mshield != null and mshield.mag == 15,
		"POSITIVE: Fairy Heart grants 15 Shield (got %s)" % [mshield.mag if mshield else "none"])
	_check(mshield != null and mshield.duration == 6,
		"POSITIVE: for 3 turns (dur %s, expect 6)" % [mshield.duration if mshield else "none"])
	_check(_named(mavis, "Fairy Heart", EffectType.Type.INVULN, mavis) == null,
		"POSITIVE: Fairy Heart grants NO Invulnerability any more")
	_check(mavis.marked_by("Fairy Heart", mavis) != null, "[control] the cannot-act lockout mark is still there")

	# --- Muichiro: 20% dodge rising 10%/turn, durations untouched.
	var clouds = muichiro.moveset.base_abilities[2]
	_check(clouds.ability_name == "Seventh Form: Obscuring Clouds", "muichiro3 is Obscuring Clouds")
	_use(muichiro, clouds, [muichiro])
	var dodge = _named(muichiro, "Seventh Form: Obscuring Clouds", EffectType.Type.DODGE_CHANCE, muichiro)
	_check(dodge != null and dodge.mag == 20, "POSITIVE: dodge starts at 20 (got %s)" % [dodge.mag if dodge else "none"])
	_check(dodge != null and dodge.duration == 8,
		"its 4-turn duration is untouched (dur %s)" % [dodge.duration if dodge else "none"])
	var ticker = _named(muichiro, "Seventh Form: Obscuring Clouds", EffectType.Type.TICKING_TRIGGER, muichiro)
	_check(ticker != null and ticker.duration == 7,
		"the ticker duration is untouched (dur %s)" % [ticker.duration if ticker else "none"])
	clouds.ticking_trigger({"target": muichiro})
	_check(dodge != null and dodge.mag == 30,
		"POSITIVE: one tick raises it by 10 (got %s, expect 30)" % [dodge.mag if dodge else "none"])
	_check(dodge != null and "30" in str(dodge.description.call(dodge)),
		"the tooltip tracks the mutated magnitude instead of the constructor value")

	# --- Broly: the stack cap is a PRE-add guard; the heal is 5/stack.
	var shell = broly.moveset.base_abilities[3]
	var lss_passive = broly.moveset.base_abilities[4]
	_check(shell.ability_name == "Powered Shell Protect", "broly4 is Powered Shell Protect")
	_check(shell.heal_per_stack == 5,
		"POSITIVE: Powered Shell Protect heals 5 per stack (got %d)" % shell.heal_per_stack)
	var watcher = _named(broly, "Legendary Super Saiyan", EffectType.Type.HARMFUL_RECEIVE_TRIGGER, broly)
	_check(watcher != null, "[setup] the Legendary Super Saiyan watcher is installed")
	var seen := []
	for i in range(6):
		lss_passive.legendary_trigger(QueryContext.from_effect_end(watcher))
		var lss = _named(broly, "Legendary Super Saiyan", EffectType.Type.DAMAGE_MOD, broly)
		seen.append(lss.stack_count() if lss else 0)
	_check(seen.size() == 6 and seen[3] == 4, "POSITIVE: four Harmful hits give exactly 4 stacks (saw %s)" % [seen])
	_check(seen.size() == 6 and seen[4] == 4 and seen[5] == 4,
		"POSITIVE: the 5th and 6th are REFUSED — the cap holds (saw %s)" % [seen])
	_check(_named(broly, "Legendary Super Saiyan", EffectType.Type.ABILITY_SWAP, broly) != null,
		"[control] the ascension swap still fires at the cap")

	# --- Yubel: 3 stacks to arm, 6 to upgrade.
	var terror = yubel.moveset.base_abilities[2]
	var ultimate = yubel.moveset.base_abilities[4]
	_check(terror.ability_name == "Terror Incarnate", "yubel3 is Terror Incarnate")
	_check(ultimate.ability_name == "Ultimate Nightmare", "yubel5 is Ultimate Nightmare")
	var stack_mark = Effect.mark(-1, "Terror Incarnate stacks.")
	stack_mark.name_override = "Terror Incarnate"
	stack_mark.set_source(terror)
	stack_mark.stackable = true
	Character.add_allied_effect(_ctx(m, yubel), yubel, yubel, stack_mark)
	var live = _named(yubel, "Terror Incarnate", EffectType.Type.MARK, yubel)
	_check(live != null, "[setup] a stackable Terror Incarnate mark is on Yubel")
	if live != null:
		live.stacks = 2
		_check(not terror.extra_usable(yubel), "POSITIVE: Terror Incarnate is refused at 2 stacks (the old bar)")
		live.stacks = 3
		_check(terror.extra_usable(yubel), "POSITIVE: ...and allowed at 3")
		live.stacks = 5
		_check(not ultimate.extra_usable(yubel), "POSITIVE: Ultimate Nightmare is refused at 5 stacks (the old bar)")
		live.stacks = 6
		_check(ultimate.extra_usable(yubel), "POSITIVE: ...and allowed at 6")

	# --- Android 17: the bonus energy is now gated on a 3+ energy skill.
	var cycling = seventeen.moveset.base_abilities[4]
	_check(cycling.ability_name == "Infinite Energy Cycling", "seventeen5 is Infinite Energy Cycling")
	var cwatcher = _named(seventeen, "Infinite Energy Cycling", EffectType.Type.ACTION_USE_TRIGGER, seventeen)
	_check(cwatcher != null, "[setup] the cycling watcher is installed")
	# EVERY skill in his kit costs 1 base, so the only route to a 3-energy skill is
	# this passive's own +1 Random per stack — the threshold really is self-fulfilling.
	# The resulting cadence is what the probe pins down: two silent uses to build the
	# stacks, then a third that costs 3, pays out and resets.
	var skill = seventeen.moveset.base_abilities[0]
	_check(_total_cost(skill) == 1, "[baseline] his skills cost 1 before any stack (%s)" % skill.ability_name)
	if cwatcher != null:
		var cadence := []
		for i in range(4):
			var before = _pool_total(seventeen)
			var paid = _total_cost(skill)
			cycling.cycling_trigger(QueryContext.from_trigger_source(skill, cwatcher, seventeen))
			cadence.append([paid, _pool_total(seventeen) - before])
		_check(cadence[0] == [1, 0] and cadence[1] == [2, 0],
			"POSITIVE: sub-3 uses grant NO energy — the whole nerf (saw %s)" % [cadence])
		_check(cadence[2] == [3, 1],
			"POSITIVE: the use that actually costs 3 grants the bonus energy (saw %s)" % [cadence])
		_check(cadence[3] == [1, 0],
			"POSITIVE: ...and that use also reset the stacks, so the next one is cheap again (saw %s)" % [cadence])
		_check(_named(seventeen, "Infinite Energy Cycling", EffectType.Type.COST_MOD, seventeen) != null,
			"[control] a sub-3 use still adds a cost stack")


func _total_cost(ability) -> int:
	var c = ability.cost()
	var total = 0
	for e in c:
		total += c[e]
	return total
