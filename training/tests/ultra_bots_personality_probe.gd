extends Node
# P4: per-bot battle PERSONALITY — distinct skill temperature, style tuning, think-speed, and surrender grit,
# so the 30 bots don't all share one decision signature. Bare ServerConnection (pure helpers, no live battle).
#   godot --headless --path <repo> res://training/tests/ultra_bots_personality_probe.tscn

const SC = preload("res://components/server_connection.gd")
var fails := 0
func _check(c, l):
	if c: print("  PASS  " + l)
	else: fails += 1; print("  FAIL  " + l)

func _ready():
	print("=== Ultra Bots personality probe (P4) ===")
	var S = SC.new()
	var names := ["MBLD", "Kosac", "ShadowClone7", "RasenganRyu", "NichirinNova", "QuirkQueen", "DomainVega", "PillarPunch"]
	var bots := {}
	for n in names:
		bots[n] = S._build_ultra_bot_player({"username": n, "rating": 0, "preferred_team": ["naruto", "sakura", "hinata"]})

	# ---- temperature: in [sharp, sloppy], stable per bot, varies across the fleet ----
	var t_in_range := true
	var temps := {}
	for n in names:
		var t: float = S._ultra_bot_temperature(bots[n])
		temps[snappedf(t, 0.0001)] = true
		if t < SC.ULTRA_BOT_TEMP_SHARP - 0.001 or t > SC.ULTRA_BOT_TEMP_SLOPPY + 0.001:
			t_in_range = false
	_check(t_in_range, "temperature: every bot in [%.2f, %.2f]" % [SC.ULTRA_BOT_TEMP_SHARP, SC.ULTRA_BOT_TEMP_SLOPPY])
	_check(S._ultra_bot_temperature(bots["MBLD"]) == S._ultra_bot_temperature(bots["MBLD"]), "temperature: stable per bot")
	_check(temps.size() >= 6, "temperature: varies across the fleet (%d distinct of %d)" % [temps.size(), names.size()])

	# ---- rating nudge: a higher-rated bot plays sharper (lower T) ----
	var midname := ""
	for n in names:
		var bs: float = S._ultra_bot_trait(n, "skill", 0.0, 1.0)
		if bs >= 0.30 and bs <= 0.70:
			midname = n; break
	_check(midname != "", "found a mid-skill bot for the rating test (%s)" % midname)
	if midname != "":
		var b = bots[midname]
		b.rank.set_values(0, 0, 0, 0)
		var t_lo: float = S._ultra_bot_temperature(b)
		b.rank.set_values(0, 0, 0, 6000)
		var t_hi: float = S._ultra_bot_temperature(b)
		_check(t_hi < t_lo, "rating nudge: a higher-rated bot is sharper (T %.3f -> %.3f)" % [t_lo, t_hi])

	# ---- tuning: per-bot style knobs in range, vary, and the base overlay is preserved + not mutated ----
	var tun: Dictionary = S._ultra_bot_tuning(bots["Kosac"])
	var g: Dictionary = tun.get("global", {})
	_check(float(g.get("aggression", 0)) >= 0.80 and float(g.get("aggression", 0)) <= 1.25, "tuning: aggression in [0.80, 1.25]")
	_check(float(g.get("energy_thrift", -1)) >= 0.0 and float(g.get("energy_thrift", -1)) <= 0.30, "tuning: energy_thrift in [0, 0.30]")
	_check(str(tun.get("format", "")) == "aa-bot-tuning" and g.has("difficulty_tiers"), "tuning: base overlay preserved (format + difficulty_tiers)")
	var aggs := {}
	for n in names:
		aggs[snappedf(float(S._ultra_bot_tuning(bots[n]).get("global", {}).get("aggression", 0)), 0.0001)] = true
	_check(aggs.size() >= 5, "tuning: aggression varies across the fleet (%d distinct)" % aggs.size())
	var live_g: Dictionary = BattleManager._get_live_bot_tuning().get("global", {})
	_check(float(live_g.get("aggression", 1.0)) == 1.0, "tuning: the shared global cache is NOT mutated (still 1.0)")

	# ---- think-speed + surrender-tilt in range + vary; _think_seconds_for honors speed and stays clamped ----
	var sp_in := true
	var speeds := {}
	for n in names:
		var sp: float = S._ultra_bot_think_speed(bots[n])
		speeds[snappedf(sp, 0.0001)] = true
		if sp < 0.6 - 0.001 or sp > 1.5 + 0.001:
			sp_in = false
	_check(sp_in and speeds.size() >= 5, "think-speed: per-bot in [0.6, 1.5], varies (%d distinct)" % speeds.size())
	var fast: float = S._think_seconds_for(3, 0.6)
	var slow: float = S._think_seconds_for(3, 1.5)
	_check(fast < slow, "think-time: a snappy bot moves faster than a deliberate one (%.2f < %.2f)" % [fast, slow])
	_check(fast >= 2.5 and slow <= 11.0, "think-time: still clamped to the [2.5, 11] human band")
	var grit_in := true
	for n in names:
		var gr: float = S._ultra_bot_surrender_tilt(bots[n])
		if gr < 0.5 - 0.001 or gr > 1.5 + 0.001:
			grit_in = false
	_check(grit_in, "surrender-tilt: per-bot in [0.5, 1.5]")

	print("=== DONE — %d FAIL(s) ===" % fails)
	get_tree().quit()
