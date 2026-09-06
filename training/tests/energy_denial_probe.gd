extends Node

# Energy-drain denial probe.
#
# Pins the owner's semantics for the rule that replaced the old vacuous
# "empty pool -> drain does nothing" bail: an unpayable drain is charged
# against the drained TEAM's next energy generation, and any leftover is
# FORGIVEN rather than carried into a second turn.
#
# Every assertion here is an OBSERVABLE outcome — the actual contents of the
# pool after a real BattleManager.generate_team_energy — and every drain goes
# through the real funnel Character.lose_energy(drainer, val), not the team
# helper, so a regression anywhere on that path is caught.
# Run: godot --headless --path <repo> res://training/tests/energy_denial_probe.tscn

var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  PASS  ", label, ("" if detail == "" else "  (" + detail + ")"))
	else:
		failures += 1
		print("  FAIL  ", label, ("" if detail == "" else "  (" + detail + ")"))

func _build_player(u, names) -> Player:
	var p: Player = load("res://components/player_component.tscn").instantiate()
	p.username = u; p.set_username(u); p.mission_reference = {}; p.mission_data = {}
	p.bot_player = true; p.bot_turn_delay = 0
	var is_enemy: bool = (u == "ZZ_Enemy")
	for cn in names: p.recruit_character(Character.from_character_name(cn), is_enemy)
	for c in p.team.characters: c.bot_character = true
	return p

func pool_total(team) -> int:
	var t := 0
	for key in team.energy.pool:
		t += team.energy.pool[key]
	return t

func set_pool(team, green: int) -> void:
	for key in team.energy.pool:
		team.energy.pool[key] = 0
	team.energy.pool[Energy.Type.GREEN] = green
	team.energy.clear_promised_pool()

## Roll a normal generation and report how many points actually landed.
func generate(manager, team) -> int:
	var before := pool_total(team)
	manager.generate_team_energy(team)
	return pool_total(team) - before

var last_gain: Array = []
var gain_emits := 0
func _on_gain(_role, energy_list: Array) -> void:
	last_gain = energy_list.duplicate()
	gain_emits += 1

func _ready():
	print("=== energy drain -> generation denial probe ===")
	var manager := BattleManager.new()
	manager.name = "BattleManager"
	manager.shadow_mode = true
	add_child(manager)
	var p1 := _build_player("ZZ_Player", ["naruto", "orihime", "diane"])
	var p2 := _build_player("ZZ_Enemy", ["eren", "mash", "squalo"])
	manager.random_panel_needed.connect(func(_t, _r, _e): pass)
	manager.start_battle(p1, p2, true, 4242, BattleManager.MatchType.BOT)

	var team = manager.enemy.team
	var victim = team.characters[0]          # every drain below lands on THIS character
	var drainer = manager.player.team.characters[0]
	check("setup: 3 living characters on the drained team", team.characters.size() == 3)

	# --- 1: BASELINE. A drain against a team that CAN pay is unchanged, and the
	# next generation is completely normal. If this reddens, ordinary drain broke.
	set_pool(team, 3)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	check("baseline: pool of 3, drain 2 -> 1 left", pool_total(team) == 1, str(pool_total(team)))
	check("baseline: nothing is owed", team.denied_energy_generation == 0,
		str(team.denied_energy_generation))
	check("baseline: next generation is the full 3", generate(manager, team) == 3)
	check("baseline: counter still 0 after generating", team.denied_energy_generation == 0)

	# --- 2: THE CORE CASE. One drain into an empty pool costs exactly one point
	# of the next generation. (Before the change this drain did nothing at all.)
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 1)
	check("empty pool, drain 1: still nothing in the pool", pool_total(team) == 0)
	var got: int = generate(manager, team)
	check("empty pool, drain 1: generation yields 2, not 3", got == 2, str(got))
	check("...and the counter is 0 afterwards", team.denied_energy_generation == 0,
		str(team.denied_energy_generation))

	# --- 3: TEAM-LEVEL (the owner's headline example). Three separate drains at
	# the SAME character while the pool is empty deny the TEAM three points — the
	# whole generation of a three-character team, even though only one character
	# was ever targeted.
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 1)
	victim.lose_energy(drainer, 1)
	victim.lose_energy(drainer, 1)
	check("3 drains on ONE character owe the TEAM 3", team.denied_energy_generation == 3,
		str(team.denied_energy_generation))
	got = generate(manager, team)
	check("3 living characters, 3 denied: the team gains NOTHING", got == 0, str(got))
	check("...and the counter is 0 afterwards", team.denied_energy_generation == 0)

	# --- 4: FORGIVENESS. The rule most likely to be "fixed" into a bug later.
	# A team that will only generate ONE point, drained for 2, loses that point
	# and NOTHING MORE — the turn after generates in full. The remainder is
	# forgiven; the denial never crosses a second turn boundary.
	team.characters[1].dead = true
	team.characters[2].dead = true
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	check("lone character, drain 2: 2 owed", team.denied_energy_generation == 2,
		str(team.denied_energy_generation))
	got = generate(manager, team)
	check("forgiveness: the single point is denied", got == 0, str(got))
	check("forgiveness: the 1 leftover is NOT carried", team.denied_energy_generation == 0,
		str(team.denied_energy_generation))
	got = generate(manager, team)
	check("forgiveness: the turn AFTER generates normally", got == 1, str(got))
	team.characters[1].dead = false
	team.characters[2].dead = false

	# --- 5: PARTIAL PAYMENT. A pool holding 1, drained for 2, pays the 1 in cash
	# right now and owes exactly 1 — not 2.
	set_pool(team, 1)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	check("partial: the 1 in the pool is taken now", pool_total(team) == 0, str(pool_total(team)))
	check("partial: exactly 1 is owed", team.denied_energy_generation == 1,
		str(team.denied_energy_generation))
	got = generate(manager, team)
	check("partial: next generation yields 2, not 3", got == 2, str(got))
	check("...and the counter is 0 afterwards", team.denied_energy_generation == 0)

	# --- 6: EXCESS SURVIVES. The denial takes POINTS, not turns — whatever the
	# team generates beyond the debt still arrives.
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	got = generate(manager, team)
	check("excess: 3 generated - 2 denied = 1 arrives", got == 1, str(got))
	check("...and the counter is 0 afterwards", team.denied_energy_generation == 0)

	# Bonus energy (Kurotsuchi, Mavis, Fern...) is credited directly and is not
	# part of the rolled generation, so a pending denial can never eat it. Owner's
	# rule 2: a team producing more than one point per character keeps the excess.
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 3)
	victim.gain_bonus_energy(Energy.Type.RED)
	check("bonus energy lands despite a full denial", pool_total(team) == 1, str(pool_total(team)))
	got = generate(manager, team)
	check("...and the rolled generation is still fully denied", got == 0, str(got))
	check("...and the counter is 0 afterwards", team.denied_energy_generation == 0)

	# --- 7: the drained team is the only one charged.
	set_pool(team, 0)
	set_pool(manager.player.team, 0)
	team.denied_energy_generation = 0
	manager.player.team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	check("the drainer's own team owes nothing",
		manager.player.team.denied_energy_generation == 0,
		str(manager.player.team.denied_energy_generation))
	check("the drainer's team generates in full", generate(manager, manager.player.team) == 3)
	got = generate(manager, team)
	check("only the drained team is short", got == 1, str(got))

	# --- 8: an unpayable drain must burn NO rolls. The old bail returned before
	# battle.roll, so the seeded stream (replays, shadow parity, seeded self-play)
	# has to be bit-identical on this branch.
	set_pool(team, 0)
	team.denied_energy_generation = 0
	var state_before = manager.die.state
	victim.lose_energy(drainer, 2)
	check("a wholly unpayable drain leaves the RNG stream untouched",
		manager.die.state == state_before)

	# --- 9: a generation that rolls nothing (whole team dead) still clears the
	# counter, or a stale debt strands and fires a turn late.
	for c in team.characters: c.dead = true
	set_pool(team, 0)
	team.denied_energy_generation = 2
	check("dead team generates nothing", generate(manager, team) == 0)
	check("an empty generation still resets the counter", team.denied_energy_generation == 0)
	for c in team.characters: c.dead = false

	# --- 10: the emitted event reports what ARRIVED, not what was rolled.
	manager.energy_gained_event.connect(_on_gain)
	set_pool(team, 0)
	team.denied_energy_generation = 1
	gain_emits = 0
	manager.generate_team_energy(team)
	check("energy_gained_event reports 2, not the 3 rolled", last_gain.size() == 2,
		str(last_gain.size()))
	set_pool(team, 0)
	team.denied_energy_generation = 3
	gain_emits = 0
	manager.generate_team_energy(team)
	check("a fully denied generation emits nothing", gain_emits == 0, str(gain_emits))

	# --- 11: the debt is on the wire (unrendered today, but available).
	team.denied_energy_generation = 2
	var snap: Dictionary = manager.serialize_wire_snapshot()
	# sides is index-stable: [0] is p1 (manager.player), [1] is p2 (manager.enemy).
	var found := int(snap["sides"][1]["energy"].get("denied_next_generation", -1))
	var other := int(snap["sides"][0]["energy"].get("denied_next_generation", -1))
	check("the wire snapshot carries denied_next_generation", found == 2, str(found))
	check("...on the drained side only", other == 0, str(other))
	team.denied_energy_generation = 0

	# --- 12: the debt does not survive into the next match.
	team.denied_energy_generation = 3
	team.reset_energy_pool()
	check("reset_energy_pool clears the counter", team.denied_energy_generation == 0)

	# ------------------------------------------------------------------------------------------
	# AFK TIMEOUT — the denial must NOT survive a skipped generation.
	# process_turn_package routes a timeout with team_mod == 3 to handle_opponent_timeout and RETURNS
	# before generate_team_energy (battle_manager.gd:1540-1546) — and generate_team_energy is the ONLY
	# place the counter is consumed. So the timed-out team never generates on this path and, without an
	# explicit clear, its debt survives to eat the generation a full round LATER. That is exactly the
	# "never crosses the next turn boundary" rule being broken.
	#
	# `passive = true` is load-bearing HERE and nowhere else: handle_opponent_timeout ends with
	# start_round_loop(), which in normal mode runs execution_loop_step() and plays out a whole turn —
	# and that downstream cycle generates energy, consuming the debt by a different route and hiding
	# the defect. In passive mode start_round_loop returns immediately (battle_manager.gd:949-951), so
	# what is measured is the skip itself. Without this the assertion is vacuous: verified by reversal,
	# it passed with the fix removed until the loop was suppressed.
	# ------------------------------------------------------------------------------------------
	set_pool(team, 0)
	team.denied_energy_generation = 0
	victim.lose_energy(drainer, 2)
	check("[timeout] an unpayable drain owes 2", team.denied_energy_generation == 2,
		str(team.denied_energy_generation))
	manager.passive = true
	manager.handle_opponent_timeout()
	manager.passive = false
	check("[timeout] the skipped generation FORGIVES the debt (never crosses the boundary)",
		team.denied_energy_generation == 0, str(team.denied_energy_generation))
	set_pool(team, 0)
	var after_timeout := generate(manager, team)
	check("[timeout] ...so the NEXT real generation is untouched (3 living characters -> 3)",
		after_timeout == 3, str(after_timeout))

	print("=== probe done: %d failure(s) ===" % failures)
	get_tree().quit(0 if failures == 0 else 1)
