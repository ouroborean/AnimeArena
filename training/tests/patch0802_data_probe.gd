extends Node

# Phase-6 data-pass probe. Reads the shipped abilities_data.json back through the SAME
# loader the battle build uses (Ability.from_database / Movesets.from_skill_count) so a
# raw-text edit that parsed but landed on the wrong row is caught at runtime, not by eye.

var failures = 0
var checks = 0


func _fail(msg):
	failures += 1
	print("FAIL  %s" % msg)


func _ok(msg):
	print("pass  %s" % msg)


func check(cond, msg):
	checks += 1
	if cond:
		_ok(msg)
	else:
		_fail(msg)


func _ready():
	_costs()
	_cooldowns()
	_flags_and_classes()
	_korra()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _cost_of(key):
	var a = Ability.from_database(key)
	if a == null:
		return null
	var c = a._cost.duplicate()
	a.queue_free()
	return c


func _expect_cost(key, green, blue, white, red, random):
	var c = _cost_of(key)
	if c == null:
		_fail("%s did not load from the database at all" % key)
		checks += 1
		return
	# JSON.parse_string hands back floats, so compare per-index as ints.
	var want = [green, blue, white, red, random]
	var got = []
	for i in range(5):
		got.append(int(c[i]))
	check(got == want, "%s cost is %s (got %s)" % [key, want, got])


func _costs():
	print("--- costs (0=GREEN 1=BLUE 2=WHITE 3=RED 4=RANDOM) ---")
	_expect_cost("eren6", 1, 0, 0, 0, 1)
	_expect_cost("eren7", 0, 0, 0, 0, 2)
	_expect_cost("eren8", 0, 0, 0, 0, 1)
	# Q20: the Blue REPLACES the Random - one pip, colour-locked, not a cost increase.
	_expect_cost("nagisa1", 0, 1, 0, 0, 0)
	_expect_cost("rob5", 0, 0, 1, 1, 0)
	_expect_cost("rob6", 0, 0, 0, 2, 1)
	_expect_cost("rob7", 0, 0, 1, 1, 0)
	_expect_cost("rob8", 0, 0, 0, 1, 1)
	_expect_cost("sukuna1", 0, 0, 0, 1, 1)
	_expect_cost("sukuna2", 0, 0, 0, 1, 1)
	# Q22: Red -> Random. Same pip count; a loosening, not a reduction.
	_expect_cost("hisoka3", 0, 0, 0, 0, 1)
	_expect_cost("mavis3", 0, 0, 2, 0, 1)
	_expect_cost("inosuke3", 0, 0, 0, 0, 0)
	_expect_cost("broly3", 1, 0, 0, 0, 1)


func _expect_cooldown(key, want):
	var a = Ability.from_database(key)
	if a == null:
		_fail("%s did not load from the database at all" % key)
		checks += 1
		return
	var got = a.cooldown
	a.queue_free()
	check(got == want, "%s printed cooldown is %d (got %d)" % [key, want, got])


func _cooldowns():
	print("--- cooldowns (PRINTED values) ---")
	_expect_cooldown("midoriya4", 2)
	_expect_cooldown("eren8", 2)
	_expect_cooldown("inuyasha3", 2)
	_expect_cooldown("itachi3", 2)
	_expect_cooldown("marco1", 1)
	# allmight5 is also named "One For All" and must NOT have moved.
	_expect_cooldown("allmight5", 0)


func _has_class(key, cls):
	var a = Ability.from_database(key)
	if a == null:
		return null
	var got = a.classes.get(cls, false)
	a.queue_free()
	return got


func _flags_and_classes():
	print("--- classes / targeting / visibility ---")
	# Q36: _skill_pierces_invuln short-circuits on the CLASS, so the script's targeting-flag
	# nerf is a no-op on the reflect-retarget path until this is false.
	check(_has_class("nimaiya1", "Bypassing") == false, "nimaiya1 no longer carries the Bypassing class")
	check(_has_class("nimaiya1", "Damaging") == true, "[control] nimaiya1 kept its other classes (Damaging)")
	# Q37: required by Mental Out's new cast-turn Piercing.
	check(_has_class("shokuhou1", "Damaging") == true, "shokuhou1 gained the Damaging class")
	check(_has_class("shokuhou1", "Control") == true, "[control] shokuhou1 kept Control")
	# Q19
	check(_has_class("kitara2", "Helpful") == true, "kitara2 gained the Helpful class")
	check(_has_class("kitara2", "Energy") == true, "[control] kitara2 kept Energy")
	# sayaka4 is Bypassing and is NOT in this patch - proves the nimaiya1 edit was row-scoped.
	check(_has_class("sayaka4", "Bypassing") == true, "[control] sayaka4 still carries Bypassing")

	# _target_type is the loaded field; target_type() is the runtime resolver.
	var k = Ability.from_database("kitara2")
	check(k != null and int(k._target_type) == 0, "kitara2 target_type is SINGLE (0), matching the allied targeter")
	if k != null:
		k.queue_free()
	var lp = Ability.from_database("lizandpatty2")
	check(lp != null and int(lp._target_type) == 0, "lizandpatty2 target_type is SINGLE (0), matching the script")
	if lp != null:
		lp.queue_free()
	var lp1 = Ability.from_database("lizandpatty1")
	check(lp1 != null and int(lp1._target_type) == 0, "[control] lizandpatty1 was already SINGLE and did not move")
	if lp1 != null:
		lp1.queue_free()

	# The row-level flag is the one that suppresses the use-flash; read it from the raw row
	# because from_database does not surface it on the Ability.
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://abilities_data.json"))
	check(rows["gogeta4"].get("invisible", false) == false, "gogeta4's row-level invisible flag is cleared")
	check(rows["hisoka3"].get("invisible", false) == true, "[control] hisoka3 kept its invisible flag")
	check(rows["hisoka3"].has("important"), "[control] hisoka3 kept its important key")


func _korra():
	print("--- Korra: the Avatar State rows are gone (Q43/Q44) ---")
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://abilities_data.json"))
	for dead in ["korra9", "korra10", "korra11"]:
		check(not rows.has(dead), "%s is no longer in abilities_data.json" % dead)
	check(rows.has("korra8"), "[control] korra8 survived the deletion")
	check(rows.has("kurapika1"), "[control] kurapika1 (the row that followed korra9) survived")

	var counts = JSON.parse_string(FileAccess.get_file_as_string("res://character_ability_counts.json"))
	check(counts["korra"] == 8, "character_ability_counts still reads korra: 8 (not double-edited)")

	# The real gate: every slot Movesets.from_skill_count would build for korra:8
	# still resolves. from_database returns null (with a push_warning) on a missing key,
	# so a null here is exactly the "row deleted out from under the moveset" failure.
	var nulls = []
	for i in range(1, int(counts["korra"]) + 1):
		var s = Ability.from_database("korra%d" % i)
		if s == null:
			nulls.append(i)
		else:
			s.queue_free()
	check(nulls.is_empty(), "all 8 of Korra's live slots still load from the database (nulls: %s)" % [nulls])
	# POSITIVE control that the null path is real, so the line above is not vacuous.
	var dead9 = Ability.from_database("korra9")
	check(dead9 == null, "korra9 no longer resolves through the loader at all")
	if dead9 != null:
		dead9.queue_free()
